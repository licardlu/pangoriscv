#include "stereo_depth.h"
#include <math.h>
#include <string.h>
#include <limits.h>

static int sample(const stereo_calibration_t*c,stereo_raw_read_t read,void*ctx,
                  unsigned side,int x,int y,uint8_t*out)
{
    *out=0;
    const stereo_camera_t*k=c->camera+side;
    const float*m=k->inverse_rectified;
    float z=m[6]*x+m[7]*y+m[8];
    if(!isfinite(z)||fabsf(z)<1e-8f)return -1;
    float a=(m[0]*x+m[1]*y+m[2])/z,b=(m[3]*x+m[4]*y+m[5])/z;
    float r=a*a+b*b,radial=1+r*(k->dist[0]+r*(k->dist[1]+r*k->dist[4]));
    float u=k->fx*(a*radial+2*k->dist[2]*a*b+k->dist[3]*(r+2*a*a))+k->cx;
    float v=k->fy*(b*radial+k->dist[2]*(r+2*b*b)+2*k->dist[3]*a*b)+k->cy;
    if(!isfinite(u)||!isfinite(v)||u<0||v<0||u>=c->width-1||v>=c->height-1)return -1;
    int ix=(int)u,iy=(int)v;
    uint8_t p[4];
    if(read(ctx,side,ix,iy,p)||read(ctx,side,ix+1,iy,p+1)||
       read(ctx,side,ix,iy+1,p+2)||read(ctx,side,ix+1,iy+1,p+3))return -1;
    float fx=u-ix,fy=v-iy;
    float value=(p[0]*(1-fx)+p[1]*fx)*(1-fy)+(p[2]*(1-fx)+p[3]*fx)*fy;
    *out=(uint8_t)(value+.5f);return 0;
}
static int patch(const stereo_calibration_t*c,stereo_raw_read_t read,void*ctx,
                 unsigned side,int x,int y,uint8_t*out)
{
    unsigned sum=0,squares=0;
    for(int j=-2;j<=2;j++)for(int i=-2;i<=2;i++){
        uint8_t value;
        if(sample(c,read,ctx,side,x+i,y+j,&value))return -1;
        out[(j+2)*5+i+2]=value;sum+=value;squares+=(unsigned)value*value;
    }
    // Reject low texture before searching: variance > 25 intensity units^2.
    return squares*25u-sum*sum>25u*625u?0:-1;
}
static int match(const stereo_calibration_t*c,stereo_raw_read_t read,void*ctx,
                 unsigned side,int x,int y,int direction,stereo_workspace_t*w)
{
    int dmax=c->max_disparity,start=direction<0?x-dmax-2:x-1;
    int width=dmax+4;
    for(int j=0;j<5;j++)for(int i=0;i<width;i++){
        unsigned p=j*STEREO_BAND+i;
        w->valid[p]=sample(c,read,ctx,side,start+i,y+j-2,&w->band[p])==0;
    }
    unsigned template_sum=0;
    for(int i=0;i<25;i++)template_sum+=w->patch[i];
    uint32_t scores[STEREO_MAX_DISPARITY+1];
    unsigned best=UINT_MAX;int best_d=0;
    for(int d=1;d<=dmax;d++){
        int offset=x+direction*d-2-start;
        unsigned sum=0;int valid=1;
        for(int j=0;j<5;j++)for(int i=0;i<5;i++){
            unsigned p=j*STEREO_BAND+offset+i;
            if(!w->valid[p])valid=0;
            sum+=w->band[p];
        }
        unsigned cost=0;
        if(valid)for(int j=0;j<5;j++)for(int i=0;i<5;i++){
            int residual=(int)w->patch[j*5+i]*25-(int)template_sum-
                         ((int)w->band[j*STEREO_BAND+offset+i]*25-(int)sum);
            cost+=(unsigned)(residual<0?-residual:residual);
        }
        scores[d]=valid?cost:UINT_MAX;
        if(scores[d]<best){best=scores[d];best_d=d;}
    }
    if(!best_d||best_d==dmax||best>25u*25u*24u)return 0;
    unsigned second=UINT_MAX;
    for(int d=1;d<=dmax;d++)if(d<best_d-1||d>best_d+1)
        if(scores[d]<second)second=scores[d];
    if(second==UINT_MAX || (uint64_t)second*100u<=(uint64_t)best*120u+625u)return 0;
    return best_d;
}
static void sort(uint16_t*a,unsigned n)
{
    for(unsigned i=1;i<n;i++){
        uint16_t value=a[i];unsigned j=i;
        while(j&&a[j-1]>value){a[j]=a[j-1];j--;}
        a[j]=value;
    }
}
int stereo_rectified_roi(const stereo_calibration_t*c,int x,int y,int w,int h,int out[4])
{
    if(!c||!out||w<12||h<12||x<0||y<0||w>c->width||h>c->height||
       x>c->width-w||y>c->height-h)return -1;
    const stereo_camera_t*k=&c->camera[0];
    if(!(k->fx>0)||!(k->fy>0))return -1;
    float lowx=c->width,lowy=c->height,highx=0,highy=0;
    for(unsigned corner=0;corner<4;corner++){
        float dx=((corner&1?x+w-1:x)-k->cx)/k->fx;
        float dy=((corner&2?y+h-1:y)-k->cy)/k->fy;
        float a=dx,b=dy;
        for(int i=0;i<8;i++){
            float r=a*a+b*b,radial=1+r*(k->dist[0]+r*(k->dist[1]+r*k->dist[4]));
            if(!isfinite(radial)||fabsf(radial)<1e-8f)return -1;
            float ta=2*k->dist[2]*a*b+k->dist[3]*(r+2*a*a);
            float tb=k->dist[2]*(r+2*b*b)+2*k->dist[3]*a*b;
            a=(dx-ta)/radial;b=(dy-tb)/radial;
        }
        const float*m=k->forward_rectified;
        float z=m[6]*a+m[7]*b+m[8];
        float u=(m[0]*a+m[1]*b+m[2])/z,v=(m[3]*a+m[4]*b+m[5])/z;
        if(!isfinite(u)||!isfinite(v)||u<0||v<0||u>=c->width||v>=c->height)return -1;
        if(u<lowx)lowx=u;
        if(u>highx)highx=u;
        if(v<lowy)lowy=v;
        if(v>highy)highy=v;
    }
    out[0]=(int)lowx;out[1]=(int)lowy;
    if((float)out[0]<lowx)out[0]++;
    if((float)out[1]<lowy)out[1]++;
    out[2]=(int)highx-out[0];out[3]=(int)highy-out[1];
    return out[0]>=2&&out[1]>=2&&out[0]+out[2]<=c->width-2&&
           out[1]+out[3]<=c->height-2&&out[2]>=12&&out[3]>=12?0:-1;
}
stereo_measurement_t stereo_measure(const stereo_calibration_t*c,stereo_raw_read_t read,void*ctx,
                                  int x,int y,int width,int height,uint32_t skew_ms,
                                  stereo_workspace_t*w)
{
    stereo_measurement_t out={0};
    if(!c||!read||!w||(c->verified&7u)!=7u||skew_ms>c->max_skew_ms||
       !c->focal_baseline_q8||!c->limit_mm||c->max_disparity<4||
       c->max_disparity>STEREO_MAX_DISPARITY||c->width<16||c->height<16||
       width<12||height<12||x<2||y<2||width>c->width||height>c->height||
       x>c->width-width-2||y>c->height-height-2)return out;
    for(unsigned side=0;side<2;side++){
        const stereo_camera_t*k=c->camera+side;
        if(!isfinite(k->fx)||!isfinite(k->fy)||k->fx<=0||k->fy<=0)return out;
    }
    out.total_points=9;
    for(int row=1;row<=3;row++)for(int col=1;col<=3;col++){
        int px=x+width*col/4,py=y+height*row/4;
        if(patch(c,read,ctx,0,px,py,w->patch))continue;
        int d=match(c,read,ctx,1,px,py,-1,w);
        if(d<=1)continue;
        if(patch(c,read,ctx,1,px-d,py,w->patch))continue;
        int reverse=match(c,read,ctx,0,px-d,py,1,w);
        if(reverse<d-1||reverse>d+1)continue;
        uint32_t depth=(c->focal_baseline_q8+(unsigned)d*128u)/((unsigned)d*256u);
        uint32_t uncertainty=c->error_mm+
            (c->focal_baseline_q8+((unsigned)d*(d-1)*256u)-1)/((unsigned)d*(d-1)*256u);
        if(!depth||depth>UINT16_MAX||uncertainty>UINT16_MAX)continue;
        unsigned i=out.valid_points++;
        w->depths[i]=(uint16_t)depth;w->uncertainty[i]=(uint16_t)uncertainty;
    }
    if(out.valid_points<5)return out;
    sort(w->depths,out.valid_points);sort(w->uncertainty,out.valid_points);
    out.low_mm=w->depths[0];out.high_mm=w->depths[out.valid_points-1];
    out.median_mm=w->depths[out.valid_points/2];
    out.uncertainty_mm=w->uncertainty[out.valid_points-1];
    if((unsigned)(out.high_mm-out.low_mm)>20u+out.median_mm/10u)return out;
    if((uint32_t)out.high_mm+out.uncertainty_mm<=c->limit_mm)out.status=STEREO_NEAR;
    else if(out.low_mm>(uint32_t)c->limit_mm+out.uncertainty_mm)out.status=STEREO_FAR;
    return out;
}
int stereo_gate_update(stereo_gate_t*g,unsigned observation,uint32_t now_ms,int reset)
{
    if(!g)return 0;
    if(reset){memset(g,0,sizeof(*g));return 0;}
    if(observation==STEREO_NEAR){
        g->far_count=0;g->last_near_ms=now_ms;
        if(g->near_count<2)g->near_count++;
        if(g->near_count>=2)g->active=1;
    }else{
        g->near_count=0;
        if(observation==STEREO_FAR){
            if(g->far_count<2)g->far_count++;
            if(g->far_count>=2)g->active=0;
        }else g->far_count=0;
        if((uint32_t)(now_ms-g->last_near_ms)>1500u)g->active=0;
    }
    return g->active;
}
