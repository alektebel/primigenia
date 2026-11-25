/* The sim's trees (island-realism plan 4.3, M3). See flora.h. */
#include "cpore/flora.h"
#include "cpore/climate.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* ---- integer hash: the same on every platform, no state shared between cells ------------------------------------------------ */
static uint32_t mix32(uint32_t x){
    x^=x>>16;x*=0x7feb352dU;x^=x>>15;x*=0x846ca68bU;x^=x>>16;
    return x;
}
static uint32_t cell_hash(uint32_t seed,int cx,int cz,uint32_t k){
    return mix32(seed*0x9E3779B1U^(uint32_t)cx*0x85EBCA6BU^mix32((uint32_t)cz*0xC2B2AE35U^k*0x27D4EB2FU));
}
static float unit(uint32_t h){return (float)(h>>8)*(1.f/16777216.f);}   /* exact: 24 bits */

static int clampi(int v,int a,int b){return v<a?a:v>b?b:v;}
static int cell_of(const CpFloraMaps *m,float x,float z,int *i,int *j){
    const float cell=m->size_m/(float)m->n,half=m->size_m*.5f;
    const float u=(x+half)/cell,v=(z+half)/cell;
    if(!(u>=0)||!(v>=0)||u>=(float)m->n||v>=(float)m->n)return 0;
    *i=clampi((int)u,0,m->n-1);*j=clampi((int)v,0,m->n-1);
    return 1;
}
static int is_pond(const CpFloraMaps *m,int k){
    return m->water_level&&m->water_level[k]-m->height[k]>.5f;
}
static int river_near(const CpFloraMaps *m,int i,int j,int span){
    if(!m->river)return 0;
    for(int y=clampi(j-span,0,m->n-1);y<=clampi(j+span,0,m->n-1);y++)
        for(int x=clampi(i-span,0,m->n-1);x<=clampi(i+span,0,m->n-1);x++)
            if(m->river[y*m->n+x]&3)return 1;
    return 0;
}
static float grade_at(const CpFloraMaps *m,int i,int j){
    const int n=m->n,i0=clampi(i-1,0,n-1),i1=clampi(i+1,0,n-1),j0=clampi(j-1,0,n-1),j1=clampi(j+1,0,n-1);
    const float cell=m->size_m/(float)n;
    const float gx=(m->height[j*n+i1]-m->height[j*n+i0])/((float)(i1-i0)*cell),gz=(m->height[j1*n+i]-m->height[j0*n+i])/((float)(j1-j0)*cell);
    return sqrtf(gx*gx+gz*gz);
}
#define MAX_GRADE 1.26f   /* flora_placement.gd MAX_GRADE: no tree on steeper ground */

/* The climate of a map cell: precipitation mm/yr (R, 0..4000) and temperature C (G, -10..+30) at the nearest climate texel. */
static void climate_at(const CpFloraMaps *m,int i,int j,float *p_mm,float *t_c){
    if(!m->climate||m->climate_n<1){*p_mm=1e9f;*t_c=1e9f;return;}   /* no climate: the biome alone decides */
    const int cn=m->climate_n;
    const int ci=clampi((int)((float)i*(float)cn/(float)m->n),0,cn-1),cj=clampi((int)((float)j*(float)cn/(float)m->n),0,cn-1);
    const uint8_t *px=m->climate+4*((size_t)cj*cn+ci);
    *p_mm=(float)px[0]*(4000.f/255.f);
    *t_c=(float)px[1]*(40.f/255.f)-10.f;
}

/* The landmark spring tree (flora.json madre_de_agua): the first dry, gentle bank on a fan east of the origin, rings of 6 m, 33 directions
 * within 80 degrees (the same search as flora_placement.gd spring_site, from the origin because the nest is not known to the field).
 * Cos and sin of the fan angles are written out so that no libm trig is used. */
static int spring_site(const CpFloraMaps *m,float *ox,float *oz){
    /* angle a_j = (j-16)*5 degrees, from the 0..80 degree tables by symmetry */
    float cs[33],sn[33];
    static const float SIN_HALF[17]={0.f,.08715574f,.17364818f,.25881905f,.34202014f,.42261826f,.50000000f,.57357644f,.64278761f,.70710678f,.76604444f,.81915204f,.86602540f,.90630779f,.93969262f,.96592583f,.98480775f};
    static const float COS_HALF[17]={1.f,.99619470f,.98480775f,.96592583f,.93969262f,.90630779f,.86602540f,.81915204f,.76604444f,.70710678f,.64278761f,.57357644f,.50000000f,.42261826f,.34202014f,.25881905f,.17364818f};
    for(int j=0;j<33;j++){
        const int d=j<16?16-j:j-16;
        cs[j]=COS_HALF[d];sn[j]=j<16?-SIN_HALF[d]:SIN_HALF[d];
    }
    for(int radius=30;radius<1500;radius+=6)for(int j=0;j<33;j++){
        const float x=(float)radius*cs[j],z=(float)radius*sn[j];
        int i,jj;
        if(!cell_of(m,x,z,&i,&jj))continue;
        const int k=jj*m->n+i;
        const float h=m->height[k];
        if(h<20.f||h>150.f||is_pond(m,k)||(m->river&&(m->river[k]&3)))continue;
        const uint8_t b=m->biome?m->biome[k]:CP_BIOME_MEADOW;
        if(b!=CP_BIOME_MEADOW&&b!=CP_BIOME_JUNGLE&&b!=CP_BIOME_DRY_FOREST&&b!=CP_BIOME_SCRUB)continue;
        if(m->trail&&m->trail[k])continue;
        if(grade_at(m,i,jj)>MAX_GRADE*.5f)continue;
        /* a freshwater margin: a river cell within 3 cells or a pond within 4 */
        if(!river_near(m,i,jj,3)){
            int pond=0;
            for(int y=clampi(jj-4,0,m->n-1);y<=clampi(jj+4,0,m->n-1)&&!pond;y++)for(int xx=clampi(i-4,0,m->n-1);xx<=clampi(i+4,0,m->n-1);xx++)if(is_pond(m,y*m->n+xx)){pond=1;break;}
            if(!pond)continue;
        }
        *ox=x;*oz=z;
        return 1;
    }
    return 0;
}

int cp_flora_trunks(const CpFloraMaps *m,CpStageTrunk *out,int cap){
    if(!m||m->n<2||!(m->size_m>0)||!m->height||!m->veg||!m->biome)return -1;
    const float half=m->size_m*.5f;
    const int side=(int)ceilf(m->size_m/CP_FLORA_GRID_M);
    const float gap2=CP_FLORA_MIN_GAP_M*CP_FLORA_MIN_GAP_M;
    int32_t *slot=(int32_t *)malloc((size_t)side*(size_t)side*sizeof *slot);   /* the accepted record of each grid cell, or -1 */
    if(!slot)return -1;
    for(size_t c=0;c<(size_t)side*(size_t)side;c++)slot[c]=-1;
    int count=0;
    float sx=0,sz=0;
    const int spring=spring_site(m,&sx,&sz);
    if(spring){
        if(count<cap)out[count]=(CpStageTrunk){sx,sz,1.6f,28.f+unit(cell_hash(m->seed,7,11,5))*4.f,CP_FLORA_SP_MADRE};
        count++;
    }
    for(int cz=0;cz<side;cz++)for(int cx=0;cx<side;cx++){
        const uint32_t h0=cell_hash(m->seed,cx,cz,1);
        const float x=(float)cx*CP_FLORA_GRID_M-half+unit(h0)*CP_FLORA_GRID_M,z=(float)cz*CP_FLORA_GRID_M-half+unit(cell_hash(m->seed,cx,cz,2))*CP_FLORA_GRID_M;
        int i,j;
        if(!cell_of(m,x,z,&i,&j))continue;
        const int k=j*m->n+i;
        const uint8_t b=m->biome[k];
        if(b!=CP_BIOME_JUNGLE&&b!=CP_BIOME_DRY_FOREST)continue;
        const float canopy=(float)m->veg[4*(size_t)k]*(1.f/255.f);
        if(canopy<.3f)continue;                                         /* flora.json nieblon climate.canopy [0.3, 1] */
        if(!(unit(cell_hash(m->seed,cx,cz,3))<canopy*CP_FLORA_ACCEPT))continue;
        const float hg=m->height[k];
        if(hg<10.f||hg>950.f||is_pond(m,k)||(m->trail&&m->trail[k]))continue;   /* altitude 10..950 (climate block), no trees on the game trails */
        float p_mm,t_c;
        climate_at(m,i,j,&p_mm,&t_c);
        if(p_mm<900.f||t_c<7.f)continue;                                /* nieblon p_mm [900, 5000], t_c [7, 30] */
        if(river_near(m,i,j,2)||grade_at(m,i,j)>MAX_GRADE)continue;
        if(spring){const float dx=x-sx,dz=z-sz;if(dx*dx+dz*dz<64.f)continue;}
        {   int cave=0;
            for(int q=0;q<m->n_caves&&!cave;q++){const float dx=x-m->cave_xz[2*q],dz=z-m->cave_xz[2*q+1];cave=dx*dx+dz*dz<CP_FLORA_CAVE_CLEAR_M*CP_FLORA_CAVE_CLEAR_M;}
            if(cave)continue;
        }
        int near=0;                                                      /* Poisson rejection against the accepted trunks of the 3x3 grid cells */
        for(int y=cz-1;y<=cz+1&&!near;y++)for(int xx=cx-1;xx<=cx+1;xx++){
            if(y<0||xx<0||y>=side||xx>=side)continue;
            const int32_t s=slot[(size_t)y*side+xx];
            if(s<0||s>=cap)continue;
            const float dx=out[s].x-x,dz=out[s].z-z;
            if(dx*dx+dz*dz<gap2){near=1;break;}
        }
        if(near)continue;
        const float height=12.f+unit(cell_hash(m->seed,cx,cz,4))*10.f;
        if(count<cap)out[count]=(CpStageTrunk){x,z,height*CP_FLORA_RADIUS_PER_M,height,CP_FLORA_SP_NIEBLON};
        slot[(size_t)cz*side+cx]=count<cap?count:-1;
        count++;
    }
    free(slot);
    return count;
}

void cp_flora_cover(const CpFloraMaps *m,uint8_t *cover){
    const size_t nn=(size_t)m->n*(size_t)m->n;
    for(size_t k=0;k<nn;k++){
        const uint8_t g=m->veg?m->veg[4*k+1]:0;
        cover[k]=(m->trail&&m->trail[k])?0:(g?g:1);
    }
}

/* ---- the spatial hash --------------------------------------------------------------------------------------------------------- */
int32_t cp_stage_trunks_cells(float size_m){
    return (int32_t)ceilf(size_m/CP_FLORA_TRUNK_CELL_M);
}
static int bucket_of(float v,float half,int cn){
    int c=(int)((v+half)/CP_FLORA_TRUNK_CELL_M);
    return clampi(c,0,cn-1);
}
int cp_stage_trunks_index(CpStageTrunks *out,const CpStageTrunk *rec,int count,float size_m,int32_t *start,int32_t *index){
    if(!out||count<0||!(size_m>0)||!start||(count&&(!rec||!index)))return -1;
    const int cn=cp_stage_trunks_cells(size_m);
    const float half=size_m*.5f;
    const size_t cells=(size_t)cn*(size_t)cn;
    memset(start,0,(cells+1)*sizeof *start);
    for(int r=0;r<count;r++)start[(size_t)bucket_of(rec[r].z,half,cn)*cn+bucket_of(rec[r].x,half,cn)+1]++;
    for(size_t c=0;c<cells;c++)start[c+1]+=start[c];
    int32_t *fill=(int32_t *)malloc(cells*sizeof *fill);
    if(!fill)return -1;
    memcpy(fill,start,cells*sizeof *fill);
    for(int r=0;r<count;r++)index[fill[(size_t)bucket_of(rec[r].z,half,cn)*cn+bucket_of(rec[r].x,half,cn)]++]=r;
    free(fill);
    out->count=count;out->cell_n=cn;out->cell=CP_FLORA_TRUNK_CELL_M;out->rec=rec;out->start=start;out->index=index;
    return 0;
}

/* ---- the field builder ---------------------------------------------------------------------------------------------------------- */
void cp_field_store_free(CpFieldStore *st){
    if(!st)return;
    free(st->cover);free(st->rec);free(st->start);free(st->index);
    memset(st,0,sizeof *st);
}
int cp_field_build(CpStageField *f,CpFieldStore *st,const CpFloraMaps *m,uint64_t terrain_hash,float cover_slow,float trail_bonus,const CpStageTrunk *given,int given_n){
    cp_field_store_free(st);
    f->cover=NULL;f->trunks=NULL;f->cover_slow=0;f->trail_bonus=0;
    if(m&&m->veg&&m->biome&&m->height&&m->n==f->n){
        const size_t nn=(size_t)m->n*(size_t)m->n;
        st->cover=(uint8_t *)malloc(nn);
        int cap=given?given_n:1<<16,count;
        st->rec=(CpStageTrunk *)malloc((size_t)(cap>0?cap:1)*sizeof *st->rec);
        if(!st->cover||!st->rec){cp_field_store_free(st);return -1;}
        cp_flora_cover(m,st->cover);
        if(given){memcpy(st->rec,given,(size_t)given_n*sizeof *st->rec);count=given_n;}
        else while((count=cp_flora_trunks(m,st->rec,cap))>cap){
            free(st->rec);cap=count+count/4+16;
            st->rec=(CpStageTrunk *)malloc((size_t)cap*sizeof *st->rec);
            if(!st->rec){cp_field_store_free(st);return -1;}
        }
        if(count<0){cp_field_store_free(st);return -1;}
        const size_t cells=(size_t)cp_stage_trunks_cells(m->size_m)*(size_t)cp_stage_trunks_cells(m->size_m);
        st->start=(int32_t *)malloc((cells+1)*sizeof *st->start);
        st->index=(int32_t *)malloc((size_t)(count?count:1)*sizeof *st->index);
        if(!st->start||!st->index||cp_stage_trunks_index(&st->trunks,st->rec,count,m->size_m,st->start,st->index)){cp_field_store_free(st);return -1;}
        f->cover=st->cover;f->trunks=&st->trunks;f->cover_slow=cover_slow;f->trail_bonus=trail_bonus;
    }
    cp_stage_field_seal(f,terrain_hash);
    return 0;
}
