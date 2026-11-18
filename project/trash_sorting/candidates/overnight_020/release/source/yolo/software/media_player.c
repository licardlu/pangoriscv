#include "media_player.h"
#include "media_sdmmc.h"
#include "media_fat32.h"
#include "media_pmj.h"
#include <string.h>
enum {INIT=0,LOAD=1,SECTOR=2,DRAIN=3,DECODE=4,PACE=5,SWAP=6,ERROR_WAIT=7};
static media_player_io_t io;
static media_player_stats_t stats;
static media_sdmmc_t card;
static media_fat32_t fs;
static media_file_t file;
/* Index entries live near the file header, while JPEG payloads advance far
 * beyond it. Independent seek cursors avoid walking the payload FAT chain
 * from its beginning again for every frame. Both still use real FAT links. */
static media_file_t index_file;
static media_file_t audio_file;
static media_pmj_t movie;
static media_pmj_frame_t frame;
static uint32_t hz,offset,left,take,started,epoch,sequence;
static uint16_t screen_width,screen_height;
static uint8_t active,clock_started,diagnostic_pause;
static uint8_t audio_present,audio_pending,audio_filling;
static uint32_t audio_offset,audio_take,audio_started,audio_crc,frame_started,decode_lead_ms;
static uint32_t displayed_sequence,displayed_sample;
static int read_reg(void*c,uint32_t a,uint32_t*v){(void)c;return io.read(io.context,a,v);}
static int write_reg(void*c,uint32_t a,uint32_t v){(void)c;return io.write(io.context,a,v);}
static uint32_t now(void*c){(void)c;return io.milliseconds(io.context);}
static int cancelled(void*c){(void)c;return io.page(io.context)!=2;}
static int read_file(void*c,uint32_t o,void*d,uint32_t n){return media_fat32_read(c,o,d,n);}
static int put(uint32_t a,uint32_t v){return write_reg(0,a,v)?SDMMC_IO:0;}
static int get(uint32_t a,uint32_t*v){return read_reg(0,a,v)?SDMMC_IO:0;}
static uint32_t u32(const uint8_t*b){return (uint32_t)b[0]|(uint32_t)b[1]<<8|(uint32_t)b[2]<<16|(uint32_t)b[3]<<24;}
static int open_audio(void){
    uint8_t h[512],binding[4];int e;
    audio_present=0;audio_pending=0;audio_filling=1;audio_offset=512;
    if((e=put(0x300,2)))return e;
    e=media_fat32_open(&fs,"PROMO   PCM",&audio_file);
    if(e==MEDIA_NOT_FOUND)return 0; /* Existing video-only cards still play. */
    if(e || (e=media_fat32_read(&audio_file,0,h,sizeof h)) ||
       (e=media_fat32_read(&index_file,36,binding,4)))return e;
    uint32_t expected=u32(h+36);memset(h+36,0,4);
    if(~media_crc32_update(~0u,h,sizeof h)!=expected)return PMJ_CRC;
    uint32_t samples=(uint32_t)((uint64_t)movie.count*48000/movie.fps);
    if(memcmp(h,"PANGPC01",8) || u32(h+8)!=1 || u32(h+12)!=48000 ||
       u32(h+16)!=samples || u32(h+20)!=movie.count || u32(h+24)!=movie.fps ||
       u32(h+28)!=u32(binding) || h[40]!=2 || h[41] || h[42]!=16 || h[43] ||
       (uint64_t)samples*4+512!=audio_file.size)return PMJ_FORMAT;
    audio_crc=u32(h+32);audio_present=1;return 0;
}
/* Service only between JPEG SD sectors. SD CRC is checked before either
 * consumer drains the shared card FIFO. PCM has priority below its watermark. */
static int service_audio(void){
    uint32_t v;int e;media_extent_t extent;
    if(!audio_present)return 0;
    if(audio_pending){
        if((e=get(0x308,&v)))return e;
        if(v&2)return SDMMC_IO;
        if(v&1)return (uint32_t)(now(0)-audio_started)>500?SDMMC_TIMEOUT:1;
        audio_offset+=audio_take;audio_pending=0;return 1;
    }
    if(stats.state==DRAIN)return 0;
    if((e=get(0x30c,&v)))return e;
    if(!audio_filling && v>1024)return 0;
    audio_filling=1;
    if(v>=1792){audio_filling=0;return 0;}
    if(audio_offset==audio_file.size){
        if((e=get(0x31c,&v)))return e;
        if(v!=audio_crc)return PMJ_CRC;
        if((e=put(0x308,2)))return e;
        audio_offset=512;
    }
    if((e=media_fat32_map(&audio_file,audio_offset,&extent)) ||
       (e=media_sdmmc_read_begin(&card,extent.lba)) ||
       (e=put(0x304,extent.skip|(extent.length<<16))) || (e=put(0x308,1)))return e;
    audio_take=extent.length;audio_started=now(0);audio_pending=1;return 1;
}
static void transition(uint32_t state){stats.state=state;started=now(0);}
static void stop(void){
    (void)put(0x300,2);audio_pending=0;
    (void)put(0x100,8);media_sdmmc_abort(&card);active=0;clock_started=0;stats.state=INIT;
}
static void fail(int e){
    (void)put(0x300,2);audio_pending=0;
    (void)put(0x100,8);media_sdmmc_abort(&card);
    if(cancelled(0)){active=0;clock_started=0;stats.state=INIT;return;}
    stats.errors++;stats.last_error=e;(void)put(0x10c,3);transition(ERROR_WAIT);
}
void media_player_setup(const media_player_io_t*p,uint32_t clock_hz,uint16_t width,uint16_t height){
    io=*p;hz=clock_hz;screen_width=width;screen_height=height;
    memset(&stats,0,sizeof stats);memset(&card,0,sizeof card);
    active=0;clock_started=0;sequence=0;diagnostic_pause=0;audio_present=0;audio_pending=0;decode_lead_ms=50;
    displayed_sequence=0;displayed_sample=0;
}
const media_player_stats_t *media_player_statistics(void){return &stats;}
int media_player_audio_statistics(uint32_t result[9]){
    static const uint16_t addresses[4]={0x300,0x30c,0x310,0x314};
    for(unsigned i=0;i<4;i++)if(get(addresses[i],result+i))return -1;
    result[4]=audio_present;result[5]=displayed_sequence;result[6]=movie.fps;result[7]=movie.count;result[8]=displayed_sample;
    return 0;
}
void media_player_pause(int paused){
    diagnostic_pause=paused!=0;
    if(audio_present&&clock_started)(void)put(0x300,!diagnostic_pause);
}
int media_player_paused(void){return diagnostic_pause;}
int media_player_load_model(uint32_t length,uint32_t expected_crc,
                            media_model_write_fn write,void*context){
    uint8_t buffer[512];uint32_t crc=~0u;int e;
    if(active || !write || !length || (length&7u))return MEDIA_RANGE;
    /* Boot reads run on page 0, so they must not use playback's page-2
     * cancellation predicate. Reuse the inactive player's FAT/SD storage. */
    media_sdmmc_io_t bus={read_reg,write_reg,now,0,0};
    media_sdmmc_setup(&card,&bus,hz);
    if((e=media_sdmmc_init(&card)) ||
       (e=media_fat32_mount(&fs,media_sdmmc_sector_callback,&card,card.sectors)) ||
       (e=media_fat32_open(&fs,"MODEL   BIN",&file)))return e;
    if(file.size!=length)return MEDIA_FORMAT;
    for(uint32_t offset=0;offset<length;){
        uint32_t n=length-offset;if(n>sizeof buffer)n=sizeof buffer;
        if((e=media_fat32_read(&file,offset,buffer,n)))return e;
        crc=media_crc32_update(crc,buffer,n);
        if((e=write(context,offset,buffer,n)))return e;
        offset+=n;
    }
    return ~crc==expected_crc?0:PMJ_CRC;
}
void media_player_poll(void){
    uint32_t value,t;int e;
    if(cancelled(0)){if(active)stop();diagnostic_pause=0;return;}
    if(diagnostic_pause)return;
    if(!active){active=1;clock_started=0;sequence=0;transition(INIT);}
    if(stats.state!=INIT && stats.state!=ERROR_WAIT){
        e=service_audio();if(e<0){fail(e);return;}if(e)return;
    }
    switch(stats.state){
    case INIT:{
        media_sdmmc_io_t bus={read_reg,write_reg,now,cancelled,0};
        media_sdmmc_setup(&card,&bus,hz);(void)put(0x10c,1);
        if((e=media_sdmmc_init(&card)) ||
           (e=media_fat32_mount(&fs,media_sdmmc_sector_callback,&card,card.sectors)) ||
           (e=media_fat32_open(&fs,"PROMO   PMJ",&file))){fail(e);return;}
        index_file=file;
        media_pmj_reader_t reader={read_file,&index_file,index_file.size};
        if((e=media_pmj_open(&movie,&reader))){fail(e);return;}
        if(movie.width!=screen_width || movie.height!=screen_height){fail(PMJ_FORMAT);return;}
        if((e=open_audio())){fail(e);return;}
        clock_started=0;sequence=0;transition(LOAD);break;
    }
    case LOAD:
        if(clock_started){
            uint32_t current;
            if(audio_present){
                if((e=get(0x310,&t))){fail(e);return;}
                /* Decode ahead of the audio clock, then present at its target
                 * PTS. Include one display refresh for the publish handshake. */
                current=(uint32_t)(((uint64_t)t+(decode_lead_ms+17u)*48u)*movie.fps/48000u);
            }else{t=(uint32_t)(now(0)-epoch);current=(uint32_t)((uint64_t)t*movie.fps/1000);}
            if(current>sequence){stats.skipped+=current-sequence;sequence=current;}
        }
        stats.index=sequence%movie.count;
        frame_started=now(0);
        if((e=media_pmj_frame(&movie,stats.index,&frame)) ||
           (e=put(0x108,frame.crc32)) || (e=put(0x100,1))){fail(e);return;}
        offset=frame.offset;left=frame.length;transition(SECTOR);break;
    case SECTOR:{
        media_extent_t extent;
        if(!left){if((e=put(0x100,4))){fail(e);return;}transition(DECODE);break;}
        if((e=media_fat32_map(&file,offset,&extent)) || (e=media_sdmmc_read_begin(&card,extent.lba))){fail(e);return;}
        take=extent.length;if(take>left)take=left;
        if((e=put(0x104,extent.skip|(take<<16))) || (e=put(0x100,2))){fail(e);return;}
        transition(DRAIN);break;
    }
    case DRAIN:
        if((e=get(0x114,&value))){fail(e);return;}
        if(value&4){fail(SDMMC_IO);return;}
        if(!(value&1)){offset+=take;left-=take;transition(SECTOR);}
        else if((uint32_t)(now(0)-started)>500)fail(SDMMC_TIMEOUT);
        break;
    case DECODE:
        if((e=get(0x114,&value))){fail(e);return;}
        if(value&4){fail(SDMMC_IO);return;}
        if(!(value&2)){if((uint32_t)(now(0)-started)>2000)fail(SDMMC_TIMEOUT);break;}
        if((e=get(0x110,&value))){fail(e);return;}
        if(value!=frame.crc32){fail(PMJ_CRC);return;}
        if((e=get(0x200,&value))){fail(e);return;}
        if(value&1){fail(PMJ_FORMAT);return;}
        if(value&2){
            uint32_t work=(uint32_t)(now(0)-frame_started);if(work>500)work=500;
            decode_lead_ms=(decode_lead_ms*3+work)/4;transition(PACE);
        }
        else if((uint32_t)(now(0)-started)>2000)fail(SDMMC_TIMEOUT);
        break;
    case PACE:
        if(clock_started){
            if(audio_present){
                if((e=get(0x310,&value))){fail(e);return;}
                uint64_t target=(uint64_t)sequence*48000/movie.fps;
                if(value<target)break;
                if((uint64_t)value>target+9600u){
                    stats.skipped++;if((e=put(0x100,8))){fail(e);return;}transition(LOAD);break;
                }
            }else if((uint64_t)(uint32_t)(now(0)-epoch)<(uint64_t)sequence*1000/movie.fps)break;
        }
        if((e=put(0x200,1))){fail(e);return;}transition(SWAP);break;
    case SWAP:
        if((e=get(0x208,&value))){fail(e);return;}
        if(!value){
            stats.frames++;stats.last_error=0;(void)put(0x10c,2);
            displayed_sequence=sequence;
            if(audio_present && (e=get(0x310,&displayed_sample))){fail(e);return;}
            if(!clock_started){
                epoch=now(0);clock_started=1;sequence=0;
                if(audio_present && (e=put(0x300,1))){fail(e);return;}
            }
            sequence++;transition(LOAD);
        }else if((uint32_t)(now(0)-started)>250)fail(SDMMC_TIMEOUT);
        break;
    case ERROR_WAIT:
        if((uint32_t)(now(0)-started)>=1000)transition(INIT);
        break;
    default:fail(PMJ_FORMAT);break;
    }
}
