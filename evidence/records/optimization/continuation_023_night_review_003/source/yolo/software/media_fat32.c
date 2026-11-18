#include "media_fat32.h"
#include <string.h>

static uint16_t le16(const uint8_t *p){return (uint16_t)(p[0]|((uint16_t)p[1]<<8));}
static uint32_t le32(const uint8_t *p){return (uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static int valid_cluster(const media_fat32_t *f,uint32_t c){return c>=2 && c<=f->clusters+1;}
static int block(media_fat32_t *f,uint32_t lba,uint8_t *out){
    if(lba<f->partition || lba-f->partition>=f->total_sectors)return MEDIA_RANGE;
    return f->read(f->context,lba,out)?MEDIA_IO:MEDIA_OK;
}
static int next_cluster(media_fat32_t *f,uint32_t c,uint32_t *next){
    uint32_t sector=f->fat_start+c/128;int rc;
    if(!valid_cluster(f,c) || c/128>=f->fat_sectors)return MEDIA_CHAIN;
    if(!f->fat_cached || f->cached_fat_sector!=sector){
        rc=block(f,sector,f->fat_cache);if(rc)return rc;
        f->cached_fat_sector=sector;f->fat_cached=1;
    }
    *next=le32(f->fat_cache+(c%128)*4)&0x0fffffffu;
    if(*next>=0x0ffffff8u)return MEDIA_EOF;
    return valid_cluster(f,*next)?MEDIA_OK:MEDIA_CHAIN;
}
int media_fat32_mount(media_fat32_t *f,media_sector_read_fn reader,void *ctx,uint32_t capacity){
    uint32_t part=0,partition_size=capacity,total,reserved,fat_size,clusters,root,i;
    uint8_t *b,spc,nfats;uint64_t metadata,end;
    if(!f || !reader)return MEDIA_FORMAT;
    memset(f,0,sizeof *f);f->read=reader;f->context=ctx;b=f->sector;
    if(reader(ctx,0,b))return MEDIA_IO;
    if(b[510]!=0x55 || b[511]!=0xaa)return MEDIA_FORMAT;
    if(le16(b+11)!=512 || le16(b+17)!=0 || le16(b+22)!=0){
        for(i=0;i<4;i++){
            const uint8_t *p=b+446+16*i;
            if(p[4]==0x0b || p[4]==0x0c){part=le32(p+8);partition_size=le32(p+12);break;}
        }
        if(!part || !partition_size || (capacity && ((uint64_t)part+partition_size>capacity)))return MEDIA_FORMAT;
        if(reader(ctx,part,b))return MEDIA_IO;
    }
    if(b[510]!=0x55 || b[511]!=0xaa || le16(b+11)!=512 || le16(b+17)!=0 || le16(b+22)!=0 || le16(b+19)!=0 || le16(b+42)!=0)
        return MEDIA_FORMAT;
    spc=b[13];nfats=b[16];reserved=le16(b+14);fat_size=le32(b+36);total=le32(b+32);root=le32(b+44);
    if(!spc || (spc&(spc-1)) || spc>128 || !reserved || (nfats!=1 && nfats!=2) || !fat_size || !total)
        return MEDIA_FORMAT;
    /* Only mirrored FAT32 is supported; never silently read inactive FAT0. */
    if(le16(b+40)&0x80)return MEDIA_FORMAT;
    metadata=(uint64_t)reserved+(uint64_t)nfats*fat_size;end=(uint64_t)part+total;
    if(metadata>=total || end>UINT32_MAX || (partition_size && total>partition_size))return MEDIA_FORMAT;
    clusters=(uint32_t)((total-metadata)/spc);
    if(clusters<65525 || clusters>0x0fffffedu || (uint64_t)(clusters+2)*4>(uint64_t)fat_size*512)return MEDIA_FORMAT;
    f->partition=part;f->total_sectors=total;f->fat_start=part+reserved;
    f->fat_sectors=fat_size;f->data_start=(uint32_t)(part+metadata);
    f->sectors_per_cluster=spc;f->clusters=clusters;f->root_cluster=root;
    return valid_cluster(f,root)?MEDIA_OK:MEDIA_FORMAT;
}
int media_fat32_open(media_fat32_t *f,const char name[11],media_file_t *file){
    uint32_t cluster,hops,s,e,next;int rc;
    if(!f || !name || !file || !valid_cluster(f,f->root_cluster))return MEDIA_FORMAT;
    cluster=f->root_cluster;
    for(hops=0;hops<f->clusters;hops++){
        for(s=0;s<f->sectors_per_cluster;s++){
            rc=block(f,f->data_start+(cluster-2)*f->sectors_per_cluster+s,f->sector);if(rc)return rc;
            for(e=0;e<512;e+=32){
                const uint8_t *p=f->sector+e;
                if(!p[0])return MEDIA_NOT_FOUND;
                if(p[0]==0xe5 || (p[11]&0x08) || p[11]==0x0f || memcmp(p,name,11))continue;
                if(p[11]&0x10)return MEDIA_NOT_FOUND;
                file->fs=f;file->first_cluster=((uint32_t)le16(p+20)<<16)|le16(p+26);
                file->size=le32(p+28);file->cached_cluster=file->first_cluster;file->cached_index=0;
                if(file->size && !valid_cluster(f,file->first_cluster))return MEDIA_CHAIN;
                if((uint64_t)file->size>(uint64_t)f->clusters*f->sectors_per_cluster*512)return MEDIA_RANGE;
                return MEDIA_OK;
            }
        }
        rc=next_cluster(f,cluster,&next);
        if(rc==MEDIA_EOF)return MEDIA_NOT_FOUND;
        if(rc)return rc;
        cluster=next;
    }
    return MEDIA_CHAIN; /* root chain is bounded even if corrupt/cyclic */
}
int media_fat32_map(media_file_t *file,uint32_t offset,media_extent_t *extent){
    media_fat32_t *f;uint32_t wanted,index,cluster,cluster_bytes,inside,next;int rc;
    if(!file || !file->fs || !extent)return MEDIA_FORMAT;
    if(offset>=file->size)return MEDIA_RANGE;
    f=file->fs;cluster_bytes=(uint32_t)f->sectors_per_cluster*512;
    wanted=offset/cluster_bytes;
    if(wanted>=f->clusters)return MEDIA_CHAIN;
    index=wanted>=file->cached_index?file->cached_index:0;
    cluster=index?file->cached_cluster:file->first_cluster;
    while(index<wanted){
        rc=next_cluster(f,cluster,&next);if(rc)return rc==MEDIA_EOF?MEDIA_CHAIN:rc;
        cluster=next;index++;
    }
    if(!valid_cluster(f,cluster))return MEDIA_CHAIN;
    inside=offset%cluster_bytes;extent->skip=inside%512;
    extent->lba=f->data_start+(cluster-2)*f->sectors_per_cluster+inside/512;
    extent->length=512-extent->skip;
    if(extent->length>file->size-offset)extent->length=file->size-offset;
    file->cached_cluster=cluster;file->cached_index=index;
    return MEDIA_OK;
}
int media_fat32_read(media_file_t *file,uint32_t offset,void *destination,uint32_t length){
    media_extent_t extent;int rc;uint8_t *out=destination;
    if(!file || !file->fs || (!out && length))return MEDIA_FORMAT;
    if(offset>file->size || length>file->size-offset)return MEDIA_RANGE;
    while(length){
        rc=media_fat32_map(file,offset,&extent);if(rc)return rc;
        rc=block(file->fs,extent.lba,file->fs->sector);if(rc)return rc;
        uint32_t take=extent.length;if(take>length)take=length;
        memcpy(out,file->fs->sector+extent.skip,take);out+=take;offset+=take;length-=take;
    }
    return MEDIA_OK;
}
