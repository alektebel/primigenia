/* Island desc (docs/plans/island-realism.md F0): CRC, parse errors, limits, round trip, and the parity gate:
 * the desc made from layout 1 by tools/island/from_layout.mjs + pack.mjs generates the same terrain hash as --layout 1.
 *   test_island BLOB.isl [--heavy]      (--heavy adds n = 1536) */
#include "cpore/island.h"
#include <assert.h>
#include <inttypes.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* terrain_cli hash --layout 1 --n N (seed 1, defaults), terrain v5. Under v4 these were f2a5f6596b9e205a, dc35612d7e211f85 and
 * f45b85dd9c35633a; v5 only adds the version word to the hash, the arrays are the same (checked by building the same sources
 * with CP_TERRAIN_VERSION 4: layouts 1..4 and the layout-0 goldens reproduce the old values bit for bit). */
static const struct { int n; uint64_t hash; } L1_GOLD[] = {
    {256, 0x22b9a96a06a0f163ull}, {512, 0x3ce8a977023b7d04ull}, {1536, 0x3aadf5b5c0b02987ull},
};
static const uint64_t L234_256[3] = {0x05ce8a80d6c048c7ull, 0xbb8c936b08cf7ea7ull, 0x74add642b0fd9504ull};   /* v4: 58864d88ccaa919a, e4f39102912a5a86, 25abc58f831502c1 */

typedef struct { CpTerrain t; CpTerrainWorkspace w; float *mem; uint8_t *riv; } Fixture;
static Fixture fixture(int n)
{
    Fixture f; size_t nn = (size_t)n * (size_t)n;
    memset(&f, 0, sizeof f);
    f.mem = calloc(nn * 8, sizeof(float)); assert(f.mem);
    f.t.height = f.mem; f.t.flow = f.mem + nn; f.t.sediment = f.mem + 2 * nn;
    f.w.scratch = f.mem + 3 * nn;
    f.w.recv = (int32_t *)(f.mem + 4 * nn); f.w.ups = (int32_t *)(f.mem + 5 * nn); f.w.queue = (int32_t *)(f.mem + 6 * nn);
    f.t.material = (uint8_t *)(f.mem + 7 * nn);
    f.riv = calloc(nn, 1); assert(f.riv); f.t.river = f.riv;
    return f;
}
static void release(Fixture *f) { free(f->mem); free(f->riv); }

static CpIslandDesc D, D2;
static uint8_t *blob; static size_t blen;
static uint8_t scratch[1 << 19];

static void recrc(uint8_t *b, size_t len)
{
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < len; i++) {
        if (i >= 12 && i < 16) continue;
        c ^= b[i];
        for (int k = 0; k < 8; k++) c = (c >> 1) ^ (0xEDB88320u & (0u - (c & 1u)));
    }
    c = ~c;
    for (int i = 0; i < 4; i++) b[12 + i] = (uint8_t)(c >> (8 * i));
}
static void put32(uint8_t *b, size_t at, int32_t v) { for (int i = 0; i < 4; i++) b[at + (size_t)i] = (uint8_t)((uint32_t)v >> (8 * i)); }

/* Body offsets (island.h wire format). */
#define OFF_META 16
#define OFF_COUNTS (16 + 22 * 4 + 32)
#define OFF_FEAT (OFF_COUNTS + 8 * 4)
#define FEAT_BYTES (10 * 4 + 32)

static int parse_mut(size_t at, int32_t v)   /* patch one i32 of a copy, fix the CRC, parse */
{
    uint8_t *b = malloc(blen); int rc;
    memcpy(b, blob, blen); put32(b, at, v); recrc(b, blen);
    rc = cp_island_parse(b, blen, &D2); free(b);
    return rc;
}

static void crc_and_header(void)
{
    assert(cp_island_crc32((const uint8_t *)"123456789", 9) == 0xCBF43926u);
    assert(cp_island_crc32((const uint8_t *)"", 0) == 0u);
    assert(cp_island_parse(NULL, 0, &D2) == CP_TERR_ERR_NULL);
    assert(cp_island_parse(blob, blen, NULL) == CP_TERR_ERR_NULL);
    for (size_t n = 0; n < 16; n++) assert(cp_island_parse(blob, n, &D2) == CP_TERR_ERR_ISL_TRUNC);
    assert(cp_island_parse(blob, blen - 1, &D2) == CP_TERR_ERR_ISL_TRUNC);
    {   uint8_t *b = malloc(blen + 1); memcpy(b, blob, blen); b[blen] = 0;
        assert(cp_island_parse(b, blen + 1, &D2) == CP_TERR_ERR_ISL_TRUNC);   /* the length field no longer matches */
        free(b); }
    {   uint8_t *b = malloc(blen); memcpy(b, blob, blen);
        b[0] = 'X'; assert(cp_island_parse(b, blen, &D2) == CP_TERR_ERR_ISL_MAGIC); b[0] = 'I';
        b[4] = 2; assert(cp_island_parse(b, blen, &D2) == CP_TERR_ERR_ISL_VERSION); b[4] = 1;
        b[6] = 1; assert(cp_island_parse(b, blen, &D2) == CP_TERR_ERR_ISL_VERSION); b[6] = 0;
        b[blen / 2] ^= 0x10; assert(cp_island_parse(b, blen, &D2) == CP_TERR_ERR_ISL_CRC); b[blen / 2] ^= 0x10;
        b[12] ^= 1; assert(cp_island_parse(b, blen, &D2) == CP_TERR_ERR_ISL_CRC); b[12] ^= 1;
        b[blen - 1] ^= 0x01; assert(cp_island_parse(b, blen, &D2) == CP_TERR_ERR_ISL_CRC); b[blen - 1] ^= 0x01;
        assert(cp_island_parse(b, blen, &D2) == CP_TERR_OK);
        free(b); }
    puts("island: crc and header ok");
}

static void parse_errors(void)
{
    const size_t f0 = OFF_FEAT;
    /* counts */
    assert(parse_mut(OFF_COUNTS, CP_ISL_MAX_FEAT + 1) == CP_TERR_ERR_ISL_LIMIT);
    assert(parse_mut(OFF_COUNTS, -1) == CP_TERR_ERR_ISL_LIMIT);
    assert(parse_mut(OFF_COUNTS + 4, CP_ISL_MAX_PT + 1) == CP_TERR_ERR_ISL_LIMIT);
    assert(parse_mut(OFF_COUNTS + 8, CP_ISL_MAX_TRAIL + 1) == CP_TERR_ERR_ISL_LIMIT);
    assert(parse_mut(OFF_COUNTS + 12, CP_ISL_MAX_TRAIL_PT + 1) == CP_TERR_ERR_ISL_LIMIT);
    assert(parse_mut(OFF_COUNTS + 16, CP_ISL_MAX_REGION + 1) == CP_TERR_ERR_ISL_LIMIT);
    assert(parse_mut(OFF_COUNTS + 20, CP_ISL_MAX_REGION_PT + 1) == CP_TERR_ERR_ISL_LIMIT);
    assert(parse_mut(OFF_COUNTS + 24, CP_ISL_MAX_MARK + 1) == CP_TERR_ERR_ISL_LIMIT);
    assert(parse_mut(OFF_COUNTS + 28, CP_ISL_MAX_MASK + 1) == CP_TERR_ERR_ISL_LIMIT);
    assert(parse_mut(OFF_COUNTS, D.nfeat - 1) == CP_TERR_ERR_ISL_TRUNC);       /* counts disagree with the length, CRC valid */
    assert(parse_mut(OFF_COUNTS + 28, 1) == CP_TERR_ERR_ISL_TRUNC);            /* a mask the blob does not hold */
    /* features */
    assert(parse_mut(f0, 0) == CP_TERR_ERR_ISL_FIELD);                         /* kind 0 */
    assert(parse_mut(f0, 10) == CP_TERR_ERR_ISL_FIELD);                        /* kind 10 */
    assert(parse_mut(f0 + 3 * 4, 0) == CP_TERR_ERR_ISL_FIELD);                 /* massif across 0 */
    assert(parse_mut(f0 + 4 * 4, -5) == CP_TERR_ERR_ISL_FIELD);                /* massif along < 0 */
    assert(parse_mut(f0 + 1 * 4, 16777217) == CP_TERR_ERR_ISL_FIELD);          /* beyond 2^24 */
    assert(parse_mut(f0 + 9 * 4, CP_ISL_F_SPLINE) == CP_TERR_ERR_ISL_FIELD);   /* spline is F1 */
    assert(parse_mut(f0 + 9 * 4, CP_ISL_F_SEA) == CP_TERR_ERR_ISL_FIELD);      /* sea on a massif */
    assert(parse_mut(f0 + 9 * 4, 8) == CP_TERR_ERR_ISL_FIELD);                 /* unknown flag */
    assert(parse_mut(f0 + 8 * 4, 2) == CP_TERR_ERR_ISL_FIELD);                 /* a massif with points */
    {   size_t r = f0 + 2 * FEAT_BYTES;                                         /* feature 2 is a range */
        assert(D.feat[2].kind == CP_ISL_RANGE);
        assert(parse_mut(r + 8 * 4, 1) == CP_TERR_ERR_ISL_FIELD);              /* one point */
        assert(parse_mut(r + 8 * 4, 0) == CP_TERR_ERR_ISL_FIELD);
        assert(parse_mut(r + 7 * 4, D.npt) == CP_TERR_ERR_ISL_FIELD);          /* point range past the table */
        assert(parse_mut(r + 7 * 4, -1) == CP_TERR_ERR_ISL_FIELD); }
    {   size_t pts = f0 + (size_t)D.nfeat * FEAT_BYTES;
        assert(parse_mut(pts + 2 * 4, 0) == CP_TERR_ERR_ISL_FIELD);            /* half width 0 */
        assert(parse_mut(pts, 1 << 25) == CP_TERR_ERR_ISL_FIELD); }
    /* meta */
    assert(parse_mut(OFF_META + 3 * 4, 0) == CP_TERR_ERR_ISL_FIELD);           /* scale 0 */
    assert(parse_mut(OFF_META + 3 * 4, 10001) == CP_TERR_ERR_ISL_FIELD);
    assert(parse_mut(OFF_META + 2 * 4, 7) == CP_TERR_ERR_ISL_FIELD);           /* n below the terrain minimum */
    assert(parse_mut(OFF_META + 2 * 4, 2049) == CP_TERR_ERR_ISL_FIELD);
    assert(parse_mut(OFF_META, 100) == CP_TERR_ERR_ISL_FIELD);                 /* size */
    assert(parse_mut(OFF_META + 4 * 4, 360000) == CP_TERR_ERR_ISL_FIELD);      /* wind angle */
    assert(parse_mut(OFF_META + 6 * 4, 1001) == CP_TERR_ERR_ISL_FIELD);        /* direction component */
    assert(parse_mut(OFF_META + 16 * 4, 257) == CP_TERR_ERR_ISL_FIELD);        /* stream iterations */
    assert(parse_mut(OFF_META + 15 * 4, -1) == CP_TERR_ERR_ISL_FIELD);         /* lake depth */
    /* strings: the id must be NUL-terminated and zero padded */
    {   uint8_t *b = malloc(blen); memcpy(b, blob, blen);
        memset(b + OFF_META + 88, 'a', 32); recrc(b, blen);
        assert(cp_island_parse(b, blen, &D2) == CP_TERR_ERR_ISL_FIELD);         /* no terminator */
        memcpy(b, blob, blen); b[OFF_META + 88 + 30] = 'z'; recrc(b, blen);
        assert(cp_island_parse(b, blen, &D2) == CP_TERR_ERR_ISL_FIELD);         /* data after the NUL */
        memcpy(b, blob, blen); b[OFF_META + 88] = 7; recrc(b, blen);
        assert(cp_island_parse(b, blen, &D2) == CP_TERR_ERR_ISL_FIELD);         /* a control character */
        free(b); }
    puts("island: parse errors ok");
}

static void setstr(char *d, int n, const char *s) { memset(d, 0, (size_t)n); memcpy(d, s, strlen(s)); }   /* canonical: zero padded */

static void limits_and_round_trip(void)
{
    size_t n;
    /* the shipped parse round-trips byte for byte, and the hash does not depend on the float cache */
    n = cp_island_pack(&D, scratch, sizeof scratch);
    assert(n == blen && memcmp(scratch, blob, blen) == 0);
    assert(D.neval == D.nfeat);   /* every table feature is one evaluator entry (two-point polylines) */
    assert(cp_island_hash(&D) != 0 && cp_island_hash(&D) == cp_island_hash(&D));
    {   uint64_t h = cp_island_hash(&D); int32_t keep = D.feat[0].h_cm;
        D.feat[0].h_cm++; assert(cp_island_hash(&D) != h); D.feat[0].h_cm = keep; assert(cp_island_hash(&D) == h); }
    assert(cp_island_pack(&D, scratch, 15) == 0 && cp_island_pack(&D, scratch, 200) == 0);

    /* full tables: 96 features, 1024 polyline points (one channel), 4 masks */
    D2 = D;
    D2.nfeat = CP_ISL_MAX_FEAT;
    for (int i = D.nfeat; i < CP_ISL_MAX_FEAT; i++) D2.feat[i] = D.feat[0];
    D2.npt = CP_ISL_MAX_PT;
    for (int i = D.npt; i < CP_ISL_MAX_PT; i++) { D2.pt[i].x_dm = i * 10; D2.pt[i].y_dm = -i * 10; D2.pt[i].hw_dm = 500; D2.pt[i].h_cm = 1000; }
    D2.feat[D.nfeat - 1].kind = CP_ISL_CHANNEL; D2.feat[D.nfeat - 1].pt0 = 0; D2.feat[D.nfeat - 1].npts = CP_ISL_MAX_PT; D2.feat[D.nfeat - 1].along_dm = 100;
    D2.feat[D.nfeat - 1].across_dm = 0; D2.feat[D.nfeat - 1].flags = CP_ISL_F_SEA;
    D2.nmask = CP_ISL_MAX_MASK;
    for (int m = 0; m < CP_ISL_MAX_MASK; m++) for (int i = 0; i < CP_ISL_MASK_RES * CP_ISL_MASK_RES; i++) D2.mask[m][i] = (uint8_t)(i * 7 + m);
    D2.ntrail = CP_ISL_MAX_TRAIL; D2.ntrail_pt = CP_ISL_MAX_TRAIL_PT;
    for (int i = 0; i < CP_ISL_MAX_TRAIL; i++) { D2.trail[i].pt0 = i * 8; D2.trail[i].npts = 8; setstr(D2.trail[i].kind, 16, "game_trail"); }
    for (int i = 0; i < CP_ISL_MAX_TRAIL_PT; i++) { D2.trail_pt[i][0] = i; D2.trail_pt[i][1] = -i; }
    D2.nregion = CP_ISL_MAX_REGION; D2.nregion_pt = CP_ISL_MAX_REGION_PT;
    for (int i = 0; i < CP_ISL_MAX_REGION; i++) { D2.region[i].pt0 = i * 4; D2.region[i].npts = 4; D2.region[i].w_dm = 100; setstr(D2.region[i].name, 32, "r"); }
    for (int i = 0; i < CP_ISL_MAX_REGION_PT; i++) { D2.region_pt[i][0] = i; D2.region_pt[i][1] = i; }
    D2.nmark = CP_ISL_MAX_MARK;
    for (int i = 0; i < CP_ISL_MAX_MARK; i++) { D2.mark[i].x_dm = i; D2.mark[i].y_dm = i; setstr(D2.mark[i].name, 32, "m"); }
    n = cp_island_pack(&D2, scratch, sizeof scratch);
    assert(n > 0);
    {   static CpIslandDesc D3; static uint8_t again[1 << 19];
        { int rc = cp_island_parse(scratch, n, &D3); if (rc) fprintf(stderr, "rc %d n %zu\n", rc, n); assert(rc == CP_TERR_OK); }
        assert(D3.nfeat == CP_ISL_MAX_FEAT && D3.npt == CP_ISL_MAX_PT && D3.nmask == CP_ISL_MAX_MASK);
        {   int want = 0;
            for (int i = 0; i < D3.nfeat; i++) want += (D3.feat[i].kind == CP_ISL_RANGE || D3.feat[i].kind == CP_ISL_CHANNEL) ? D3.feat[i].npts - 1 : 1;
            assert(D3.neval == want && D3.neval <= CP_ISL_MAX_EVAL); }
        assert(D3.mask[3][5] == (uint8_t)(5 * 7 + 3) && D3.trail_pt[100][1] == -100 && D3.mark[31].x_dm == 31);
        assert(cp_island_pack(&D3, again, sizeof again) == n && memcmp(again, scratch, n) == 0);
        assert(cp_island_hash(&D3) == cp_island_hash(&D2));
        /* one more of anything is refused by pack-compatible parse: patch the counts */
        scratch[OFF_COUNTS + 0] = CP_ISL_MAX_FEAT + 1; recrc(scratch, n);
        assert(cp_island_parse(scratch, n, &D3) == CP_TERR_ERR_ISL_LIMIT); }
    puts("island: limits and round trip ok");
}

static uint64_t bare_hash;   /* the last gen(): the same arrays hashed as a layout island (island_hash cleared) */
static int gen_keep(const CpTerrainParams *p, const CpIslandDesc *d, uint64_t *hash, float *height_out, uint8_t *mat_out)
{
    Fixture f = fixture(p->n); int rc;
    rc = d ? cp_terrain_generate_desc(p, d, &f.t, &f.w, NULL, NULL) : cp_terrain_generate(p, &f.t, &f.w, NULL, NULL);
    if (rc == CP_TERR_OK) {
        f.t.n = p->n; f.t.size_m = p->size_m; *hash = cp_terrain_hash(&f.t);
        if (d) assert(f.t.island_hash == cp_island_hash(d)); else assert(f.t.island_hash == 0);
        if (height_out) memcpy(height_out, f.t.height, sizeof(float) * (size_t)p->n * (size_t)p->n);
        if (mat_out) memcpy(mat_out, f.t.material, (size_t)p->n * (size_t)p->n);
        f.t.island_hash = 0; bare_hash = cp_terrain_hash(&f.t);
    }
    release(&f);
    return rc;
}
static int gen(const CpTerrainParams *p, const CpIslandDesc *d, uint64_t *hash) { return gen_keep(p, d, hash, NULL, NULL); }
static void params_for(CpTerrainParams *p, int layout, int n)
{
    cp_terrain_params_default(p);
    cp_terrain_layout_apply(layout, p);
    p->n = n;
}

static void parity(int heavy)
{
    uint64_t a, b;
    CpTerrainParams p;
    for (size_t i = 0; i < sizeof L1_GOLD / sizeof L1_GOLD[0]; i++) {
        if (L1_GOLD[i].n > 512 && !heavy) continue;
        params_for(&p, 1, L1_GOLD[i].n);
        assert(gen(&p, NULL, &a) == CP_TERR_OK);
        assert(gen(&p, &D, &b) == CP_TERR_OK);
        printf("island: n %4d  layout 1 %016" PRIx64 "  desc %016" PRIx64 "  desc arrays %016" PRIx64 "%s\n", L1_GOLD[i].n, a, b, bare_hash, a == bare_hash ? "  identical" : "  DIFFERENT");
        assert(a == L1_GOLD[i].hash);   /* the evaluator split did not move layout 1 */
        assert(bare_hash == a);         /* the gate: same arrays; v5 mixes the desc hash on top, so the full hash differs */
        assert(b != a);
    }
    /* the desc path does not read p->layout, and the other layouts did not move */
    params_for(&p, 1, 256); p.layout = 0.f;
    assert(gen(&p, &D, &b) == CP_TERR_OK && bare_hash == L1_GOLD[0].hash);
    for (int L = 2; L <= 4; L++) { params_for(&p, L, 256); assert(gen(&p, NULL, &a) == CP_TERR_OK && a == L234_256[L - 2]); }
    /* a changed desc changes the terrain; an unprepared or missing desc is refused */
    params_for(&p, 1, 256);
    D2 = D; D2.feat[0].h_cm += 5000; assert(cp_island_prepare(&D2) == CP_TERR_OK);
    assert(gen(&p, &D2, &b) == CP_TERR_OK && b != L1_GOLD[0].hash);
    memset(&D2, 0, sizeof D2);
    assert(gen(&p, &D2, &b) == CP_TERR_ERR_ISL_FIELD);
    {   Fixture f = fixture(256);
        assert(cp_terrain_generate_desc(&p, NULL, &f.t, &f.w, NULL, NULL) == CP_TERR_ERR_NULL);
        assert(cp_terrain_generate_desc(NULL, &D, &f.t, &f.w, NULL, NULL) == CP_TERR_ERR_NULL);
        release(&f); }
    puts("island: parity ok");
}


/* ---- F1: splines, noise index, masks, protect, trails, terrain v5 ------------------------------------------------- */
static CpIslandDesc SP, DT;
static float f10_(int v) { return (float)v / 10.f; }

static void spline_eval(void)
{
    const int pts[4][4] = {{0, 0, 300, 1000}, {1000, 500, 300, 2000}, {2000, -500, 400, 3000}, {3000, 0, 300, 1500}};
    memset(&SP, 0, sizeof SP);
    SP.nfeat = 3; SP.npt = 4;
    SP.feat[0].kind = CP_ISL_MASSIF; SP.feat[0].across_dm = 100; SP.feat[0].along_dm = 100;
    SP.feat[1].kind = CP_ISL_RANGE; SP.feat[1].pt0 = 0; SP.feat[1].npts = 4; SP.feat[1].flags = CP_ISL_F_SPLINE; SP.feat[1].k = 500;
    SP.feat[2].kind = CP_ISL_MASSIF; SP.feat[2].across_dm = 100; SP.feat[2].along_dm = 100;
    for (int i = 0; i < 4; i++) { SP.pt[i].x_dm = pts[i][0]; SP.pt[i].y_dm = pts[i][1]; SP.pt[i].hw_dm = pts[i][2]; SP.pt[i].h_cm = pts[i][3]; }
    SP.scale_pm = 1000; SP.nest_r_dm = 100;
    assert(cp_island_prepare(&SP) == CP_TERR_OK);
    assert(SP.neval == 1 + 3 * CP_ISL_SPLINE_SEG + 1);
    /* the curve passes through every control point, exactly: the start of each span, the end of the last */
    for (int sp = 0; sp < 3; sp++) {
        const CpIslandEval *a = &SP.eval[1 + sp * CP_ISL_SPLINE_SEG], *z = a + CP_ISL_SPLINE_SEG - 1;
        assert(a->x0 == f10_(pts[sp][0]) && a->y0 == f10_(pts[sp][1]) && a->h == (float)pts[sp][3] / 100.f);
        assert(z->x1 == f10_(pts[sp + 1][0]) && z->y1 == f10_(pts[sp + 1][1]) && z->h2 == (float)pts[sp + 1][3] / 100.f);
        for (int g = 0; g + 1 < CP_ISL_SPLINE_SEG; g++) assert(a[g].x1 == a[g + 1].x0 && a[g].y1 == a[g + 1].y0 && a[g].h2 == a[g + 1].h);   /* a connected polyline */
        for (int g = 0; g < CP_ISL_SPLINE_SEG; g++) assert(a[g].ni == 1 + sp && a[g].kind == CP_ISL_RANGE && a[g].w > 0.f);
    }
    assert(SP.eval[1].a0 == 0.f && SP.eval[2].a0 > 0.f);
    {   /* a quarter-span sample leaves the chord of the middle span: the curve bends, it is not the polyline */
        const CpIslandEval *m = &SP.eval[1 + CP_ISL_SPLINE_SEG + CP_ISL_SPLINE_SEG / 4];
        float ax = f10_(pts[1][0]), ay = f10_(pts[1][1]), bx = f10_(pts[2][0]), by = f10_(pts[2][1]);
        float cross = (bx - ax) * (m->y0 - ay) - (by - ay) * (m->x0 - ax), len = sqrtf((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
        assert((cross < 0.f ? -cross : cross) / len > 0.5f);
    }
    /* noise index: one per control span, shared by the sub-segments; spline on or off, the features after it keep their index */
    assert(SP.eval[0].ni == 0 && SP.eval[SP.neval - 1].ni == 4);
    SP.feat[1].flags = 0;
    assert(cp_island_prepare(&SP) == CP_TERR_OK && SP.neval == 5);
    for (int i = 0; i < 5; i++) assert(SP.eval[i].ni == i && SP.eval[i].a0 == 0.f);       /* straight: the evaluator-entry position (layout parity) */
    assert(SP.eval[1].x0 == 0.f && SP.eval[1].x1 == 100.f && SP.eval[3].x1 == 300.f && SP.eval[2].w == 30.f);
    /* equally spaced collinear points: the samples stay on the line and march forward */
    SP.feat[1].flags = CP_ISL_F_SPLINE; SP.feat[1].npts = 3;
    SP.pt[0].y_dm = SP.pt[1].y_dm = SP.pt[2].y_dm = 0;
    assert(cp_island_prepare(&SP) == CP_TERR_OK);
    for (int g = 1; g < 2 * CP_ISL_SPLINE_SEG; g++) { const CpIslandEval *e = &SP.eval[g]; assert(e->y0 == 0.f && e->y1 == 0.f && e->x1 > e->x0); }
    /* a desc that needs more than the evaluator holds is refused, not truncated */
    memset(&SP, 0, sizeof SP);
    SP.nfeat = 1; SP.npt = 300; SP.feat[0].kind = CP_ISL_RANGE; SP.feat[0].npts = 300; SP.feat[0].flags = CP_ISL_F_SPLINE; SP.scale_pm = 1000;
    for (int i = 0; i < 300; i++) { SP.pt[i].x_dm = i * 10; SP.pt[i].hw_dm = 100; }
    assert(cp_island_prepare(&SP) == CP_TERR_ERR_ISL_LIMIT);
    SP.feat[0].npts = 200; assert(cp_island_prepare(&SP) == CP_TERR_OK && SP.neval == 199 * CP_ISL_SPLINE_SEG);
    puts("island: spline evaluator ok");
}

static void spline_blob(void)
{
    size_t n; static CpIslandDesc S2;
    assert(D.feat[2].kind == CP_ISL_RANGE && D.feat[2].npts == 2);
    D2 = D; D2.feat[2].flags |= CP_ISL_F_SPLINE;
    assert(cp_island_prepare(&D2) == CP_TERR_OK && D2.neval == D.neval + CP_ISL_SPLINE_SEG - 1);
    n = cp_island_pack(&D2, scratch, sizeof scratch);
    assert(n == blen && memcmp(scratch, blob, blen) != 0);
    assert(cp_island_parse(scratch, n, &S2) == CP_TERR_OK && S2.neval == D2.neval && (S2.feat[2].flags & CP_ISL_F_SPLINE));
    assert(cp_island_hash(&S2) == cp_island_hash(&D2) && cp_island_hash(&D2) != cp_island_hash(&D));
    assert(S2.eval[2].ni == 2 && S2.eval[2 + CP_ISL_SPLINE_SEG].ni == 3);     /* the rest of the table keeps its index */
    for (int i = 3; i < D.nfeat; i++) assert(S2.eval[i - 1 + CP_ISL_SPLINE_SEG].ni == D.eval[i].ni);
    puts("island: spline blob ok");
}

static void masks(void)
{
    uint64_t lcg = 12345;
    D2 = D; D2.nmask = 3;
    for (int y = 0; y < CP_ISL_MASK_RES; y++) for (int x = 0; x < CP_ISL_MASK_RES; x++) {
        D2.mask[0][y * CP_ISL_MASK_RES + x] = (uint8_t)(x + 2 * y);
        D2.mask[1][y * CP_ISL_MASK_RES + x] = 128;
        D2.mask[2][y * CP_ISL_MASK_RES + x] = (x < 64) ? 40 : 200;
    }
    {   const float size = 8000.f, tx = 4000.f;
        /* texel centres return the stored value; a linear ramp is reproduced between them; the edges extend */
        for (int k = 0; k < 40; k++) {
            float u = 3.f + (float)(k * 3) * 0.91f, v = 5.f + (float)k * 1.37f;    /* texel coordinates */
            float want = u + 2.f * v, got = cp_island_mask(&D2, 0, (u + 0.5f) / 128.f * size - tx, (v + 0.5f) / 128.f * size - tx);
            assert(got > want - 0.01f && got < want + 0.01f);
        }
        assert(cp_island_mask(&D2, 0, (10.5f) / 128.f * size - tx, (20.5f) / 128.f * size - tx) == 50.f);
        assert(cp_island_mask(&D2, 0, -tx - 500.f, -tx - 500.f) == 0.f);                              /* clamped to texel (0,0) */
        assert(cp_island_mask(&D2, 0, tx + 500.f, tx + 500.f) == (float)(uint8_t)(127 + 254));
        /* a step between two texels: the midpoint is the mean */
        assert(cp_island_mask(&D2, 2, 64.f / 128.f * size - tx, 0.f) == 120.f);
        /* a constant 128 mask is exactly 128 anywhere (so a neutral mask cannot move a single bit), an absent mask too */
        for (int k = 0; k < 2000; k++) {
            float x, y;
            lcg = lcg * 6364136223846793005ull + 1442695040888963407ull; x = (float)(lcg >> 40) / 16777216.f * 9000.f - 4500.f;
            lcg = lcg * 6364136223846793005ull + 1442695040888963407ull; y = (float)(lcg >> 40) / 16777216.f * 9000.f - 4500.f;
            assert(cp_island_mask(&D2, 1, x, y) == 128.f && cp_island_mask(&D2, 3, x, y) == 128.f && cp_island_mask(&D, 2, x, y) == 128.f);
        }
        assert(cp_island_mask(NULL, 0, 0.f, 0.f) == 128.f && cp_island_mask(&D2, -1, 0.f, 0.f) == 128.f);
    }
    puts("island: masks ok");
}

static void params_quiet(CpTerrainParams *p, int n)   /* nothing after the erosion that moves a height: rivers, cave notches, cliff bands */
{
    params_for(p, 1, n);
    p->rivers = 0.f; p->cliff_bands = 0.f; p->caves = 0.f; p->volcano = 0.f;
}
static float maxdev(const float *a, const float *b, int n, int mask_half /* 0 all, 1 left half, 2 right half */)
{
    float m = 0.f;
    for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
        float d;
        if (mask_half == 1 && x >= n / 2 - 2) continue;
        if (mask_half == 2 && x < n / 2 + 2) continue;
        d = a[y * n + x] - b[y * n + x]; if (d < 0.f) d = -d;
        if (d > m) m = d;
    }
    return m;
}
static float sumdev(const float *a, const float *b, int n)
{
    double s = 0.0;
    for (int i = 0; i < n * n; i++) s += (double)(a[i] > b[i] ? a[i] - b[i] : b[i] - a[i]);
    return (float)s;
}

static void protect_and_erosion(void)
{
    const int N = 256; CpTerrainParams p; uint64_t h0, h1, hb, bare0; float *base = malloc(sizeof(float) * N * N), *eroded = malloc(sizeof(float) * N * N), *prot = malloc(sizeof(float) * N * N);
    static CpIslandDesc B, E;
    assert(base && eroded && prot);
    params_quiet(&p, N);
    /* the authored shape: no erosion at all */
    B = D; B.stream_iters = 0; B.droplets = 0; assert(cp_island_prepare(&B) == CP_TERR_OK);
    { CpTerrainParams q = p; q.stream_iters = 0; q.droplets = 0; q.thermal_iters = 0; assert(gen_keep(&q, &B, &hb, base, NULL) == CP_TERR_OK); }
    assert(gen_keep(&p, &D, &h0, eroded, NULL) == CP_TERR_OK); bare0 = bare_hash;
    assert(maxdev(base, eroded, N, 0) > 3.f);     /* erosion moves the ground, so the protect test below can fail */
    /* neutral masks (128) are no-ops, bit for bit */
    E = D; E.nmask = 4; memset(E.mask, 128, sizeof E.mask);
    assert(gen_keep(&p, &E, &h1, prot, NULL) == CP_TERR_OK && bare_hash == bare0 && memcmp(prot, eroded, sizeof(float) * N * N) == 0 && h1 != h0);
    /* protect: the left half at full value keeps the authored height within +-0.5 m; the right half is the plain eroded terrain */
    for (int y = 0; y < CP_ISL_MASK_RES; y++) for (int x = 0; x < CP_ISL_MASK_RES; x++) E.mask[CP_ISL_MASK_PROTECT][y * CP_ISL_MASK_RES + x] = x < 64 ? 255 : 128;
    assert(gen_keep(&p, &E, &h1, prot, NULL) == CP_TERR_OK);
    { float dl = maxdev(prot, base, N, 1), dr = maxdev(prot, eroded, N, 2), dlu = maxdev(eroded, base, N, 1);
      printf("island: protect  left half max |h - authored| %.4f m (unprotected %.2f m); right half vs eroded %.1e\n", (double)dl, (double)dlu, (double)dr);
      assert(dl <= 0.5f + 1e-4f); assert(dlu > 1.f); assert(dr == 0.f); }
    /* a partial value widens the band: 192 is half strength, band 1 m */
    for (int i = 0; i < CP_ISL_MASK_RES * CP_ISL_MASK_RES; i++) E.mask[CP_ISL_MASK_PROTECT][i] = 192;
    assert(gen_keep(&p, &E, &h1, prot, NULL) == CP_TERR_OK);
    { float dd = maxdev(prot, base, N, 0); assert(dd <= 1.f / (63.f / 127.f) * 0.5f + 1e-3f && dd > 0.5f); }
    /* erosion mask: 0 leaves the ground nearer the authored shape than the neutral mask does; 192 erodes more */
    E = D; E.nmask = 3; memset(E.mask, 128, sizeof E.mask);
    for (int i = 0; i < CP_ISL_MASK_RES * CP_ISL_MASK_RES; i++) E.mask[CP_ISL_MASK_EROSION][i] = 0;
    assert(gen_keep(&p, &E, &h1, prot, NULL) == CP_TERR_OK);
    { float s0 = sumdev(prot, base, N), sn = sumdev(eroded, base, N); printf("island: erosion mask 0 -> total change %.0f m vs %.0f m neutral\n", (double)s0, (double)sn); assert(s0 < 0.6f * sn); }
    for (int i = 0; i < CP_ISL_MASK_RES * CP_ISL_MASK_RES; i++) E.mask[CP_ISL_MASK_EROSION][i] = 192;
    assert(gen_keep(&p, &E, &h1, prot, NULL) == CP_TERR_OK);
    { float s2 = sumdev(prot, base, N), sn = sumdev(eroded, base, N); printf("island: erosion mask 192 -> total change %.0f m vs %.0f m neutral\n", (double)s2, (double)sn); assert(s2 > 1.05f * sn); }
    free(base); free(eroded); free(prot);
    puts("island: protect and erosion masks ok");
}

/* Can a walker go from the cells near (sx,sy) to the cells near (tx,ty), staying within 40 m of the hint polyline hx/hy (world
 * metres), with no step steeper than max_grade (rise over run, 8-connected)? */
static int bfs_walk(const float *h, int n, float cell, const float *hx, const float *hy, int nh, int sx, int sy, int tx, int ty, float max_grade)
{
    int *q = malloc(sizeof(int) * (size_t)n * (size_t)n); uint8_t *seen = calloc((size_t)n * (size_t)n, 1), *in = calloc((size_t)n * (size_t)n, 1);
    int head = 0, tail = 0, found = 0, R = (int)(20.f / cell) + 1;
    assert(q && seen && in);
    for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
        float px = ((float)x + 0.5f) * cell - 4000.f, py = ((float)y + 0.5f) * cell - 4000.f;
        for (int k = 0; k + 1 < nh; k++) {
            float sxx = hx[k + 1] - hx[k], syy = hy[k + 1] - hy[k], l2 = sxx * sxx + syy * syy, u = ((px - hx[k]) * sxx + (py - hy[k]) * syy) / l2, dx, dy;
            u = u < 0.f ? 0.f : u > 1.f ? 1.f : u;
            dx = px - (hx[k] + u * sxx); dy = py - (hy[k] + u * syy);
            if (dx * dx + dy * dy <= 40.f * 40.f) { in[y * n + x] = 1; break; }
        }
    }
    for (int dy = -R; dy <= R; dy++) for (int dx = -R; dx <= R; dx++) {
        int x = sx + dx, y = sy + dy;
        if (x >= 0 && y >= 0 && x < n && y < n && in[y * n + x] && !seen[y * n + x]) { seen[y * n + x] = 1; q[tail++] = y * n + x; }
    }
    while (head < tail && !found) {
        int c = q[head++], x = c % n, y = c / n;
        if ((x - tx) * (x - tx) + (y - ty) * (y - ty) <= R * R) found = 1;
        for (int d = 0; d < 8; d++) {
            static const int DX[8] = {1, 1, 0, -1, -1, -1, 0, 1}, DY[8] = {0, 1, 1, 1, 0, -1, -1, -1};
            int nx = x + DX[d], ny = y + DY[d], j; float g;
            if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
            j = ny * n + nx;
            if (seen[j] || !in[j]) continue;
            g = (h[j] > h[c] ? h[j] - h[c] : h[c] - h[j]) / (cell * ((d & 1) ? 1.41421356f : 1.f));
            if (g > max_grade) continue;
            seen[j] = 1; q[tail++] = j;
        }
    }
    free(q); free(seen); free(in);
    return found;
}

static void trails(void)
{
    const int N = 512; CpTerrainParams p; uint64_t ha, hb, hc, hd;
    float *h0 = malloc(sizeof(float) * N * N), *h1 = malloc(sizeof(float) * N * N); uint8_t *m1 = malloc((size_t)N * N);
    const float cell = 8000.f / (float)N;
    assert(h0 && h1 && m1);
    params_for(&p, 1, N);
    /* the shipped desc's trails are kind "exit": descriptive only, nothing carved */
    assert(gen_keep(&p, &D, &ha, h0, NULL) == CP_TERR_OK && bare_hash == L1_GOLD[1].hash);
    DT = D; DT.ntrail = 1; DT.ntrail_pt = 3; DT.trail[0].pt0 = 0; DT.trail[0].npts = 3; memset(DT.trail[0].kind, 0, 16); memcpy(DT.trail[0].kind, "game_trail", 10);
    DT.trail_pt[0][0] = 0; DT.trail_pt[0][1] = 0; DT.trail_pt[1][0] = 2500; DT.trail_pt[1][1] = -3300; DT.trail_pt[2][0] = 5600; DT.trail_pt[2][1] = -6900;
    assert(cp_island_prepare(&DT) == CP_TERR_OK);
    assert(gen_keep(&p, &DT, &hb, h1, m1) == CP_TERR_OK && bare_hash != L1_GOLD[1].hash);
    assert(gen_keep(&p, &DT, &hc, NULL, NULL) == CP_TERR_OK && hc == hb);                           /* deterministic */
    {   /* the corridor links the two ends within a grade of 0.31 (the carve grades the centre line to 0.30; the grip rule is 1.26);
         * on the ground as it was, the same corridor is not walkable at that grade, so the carve is what made it so */
        const float hx[3] = {0.f, 390.f, 873.6f}, hy[3] = {0.f, -514.8f, -1076.4f};
        int ax = (int)((0.f + 4000.f) / cell), ay = ax, bx = (int)((873.6f + 4000.f) / cell), by = (int)((-1076.4f + 4000.f) / cell), changed = 0;
        int with = bfs_walk(h1, N, cell, hx, hy, 3, ax, ay, bx, by, 0.31f), without = bfs_walk(h0, N, cell, hx, hy, 3, ax, ay, bx, by, 0.31f);
        for (int i = 0; i < N * N; i++) if (h1[i] != h0[i]) changed++;
        printf("island: trail  %d cells regraded; corridor walkable at grade 0.31 (the carve limit is 0.30): with the trail %d, without %d\n", changed, with, without);
        assert(changed > 200 && with == 1 && without == 0);
        (void)m1; }
    /* a trail that cannot be routed inside its corridor (a waypoint in the open sea) is skipped whole */
    DT.trail_pt[2][0] = 30000; DT.trail_pt[2][1] = 30000;
    assert(gen_keep(&p, &DT, &hd, NULL, NULL) == CP_TERR_OK && bare_hash == L1_GOLD[1].hash);
    /* a trail of another kind is never carved, and the unit of its points is the design unit like everything else */
    DT.trail_pt[2][0] = 5600; DT.trail_pt[2][1] = -6900; memset(DT.trail[0].kind, 0, 16); memcpy(DT.trail[0].kind, "exit", 4);
    assert(gen_keep(&p, &DT, &hd, NULL, NULL) == CP_TERR_OK && bare_hash == L1_GOLD[1].hash);
    free(h0); free(h1); free(m1);
    puts("island: trails ok");
}

static void splined_terrain(void)
{
    CpTerrainParams p; uint64_t a, b, c;
    params_for(&p, 1, 256);
    /* turning the splines on changes the terrain, deterministically; the same blob twice is the same terrain */
    D2 = D; for (int i = 0; i < D2.nfeat; i++) if (D2.feat[i].kind == CP_ISL_RANGE) { /* two-point ranges: a spline is the straight line */ }
    {   static CpIslandDesc S3; S3 = D; S3.nfeat = D.nfeat;
        /* a three-point range bent in the middle: straight vs spline differ, spline twice is stable */
        S3.npt = D.npt + 3; S3.nfeat = D.nfeat + 1; memset(&S3.feat[D.nfeat], 0, sizeof S3.feat[0]);
        S3.feat[D.nfeat].kind = CP_ISL_RANGE; S3.feat[D.nfeat].pt0 = D.npt; S3.feat[D.nfeat].npts = 3; S3.feat[D.nfeat].k = 600;
        S3.pt[D.npt].x_dm = -3000; S3.pt[D.npt].y_dm = 2000; S3.pt[D.npt].hw_dm = 400; S3.pt[D.npt].h_cm = 12000;
        S3.pt[D.npt + 1].x_dm = -1500; S3.pt[D.npt + 1].y_dm = 5500; S3.pt[D.npt + 1].hw_dm = 400; S3.pt[D.npt + 1].h_cm = 15000;
        S3.pt[D.npt + 2].x_dm = 1500; S3.pt[D.npt + 2].y_dm = 6500; S3.pt[D.npt + 2].hw_dm = 400; S3.pt[D.npt + 2].h_cm = 9000;
        assert(cp_island_prepare(&S3) == CP_TERR_OK);
        assert(gen(&p, &S3, &a) == CP_TERR_OK);
        S3.feat[D.nfeat].flags = CP_ISL_F_SPLINE; assert(cp_island_prepare(&S3) == CP_TERR_OK);
        assert(gen(&p, &S3, &b) == CP_TERR_OK && gen(&p, &S3, &c) == CP_TERR_OK);
        assert(a != b && b == c && cp_island_hash(&S3) != 0);
        assert(bare_hash != L1_GOLD[0].hash); }
    puts("island: splined terrain ok");
}

static void v5_hash(void)
{
    CpTerrainParams p; uint64_t a, b; Fixture f;
    assert(CP_TERRAIN_VERSION == 5);
    params_for(&p, 1, 64);
    f = fixture(64);
    assert(cp_terrain_generate_desc(&p, &D, &f.t, &f.w, NULL, NULL) == CP_TERR_OK);
    f.t.n = 64; f.t.size_m = p.size_m;
    a = cp_terrain_hash(&f.t);
    f.t.island_hash ^= 1; b = cp_terrain_hash(&f.t);
    assert(a != b);                       /* the desc hash is part of the terrain hash */
    f.t.island_hash = 0; b = cp_terrain_hash(&f.t);
    assert(a != b);
    release(&f);
    puts("island: terrain v5 hash ok");
}

int main(int argc, char **argv)
{
    FILE *fp; int heavy = 0;
    for (int i = 2; i < argc; i++) if (!strcmp(argv[i], "--heavy")) heavy = 1;
    if (argc < 2) { fprintf(stderr, "usage: test_island BLOB.isl [--heavy]\n"); return 2; }
    fp = fopen(argv[1], "rb"); if (!fp) { perror(argv[1]); return 2; }
    blob = malloc(1 << 20); blen = fread(blob, 1, 1 << 20, fp); fclose(fp);
    assert(blen > 16);
    assert(cp_island_parse(blob, blen, &D) == CP_TERR_OK);
    assert(D.nfeat > 20 && D.scale_pm == 1560 && D.size_dm == 80000);
    crc_and_header();
    parse_errors();
    limits_and_round_trip();
    parity(heavy);
    spline_eval();
    spline_blob();
    masks();
    v5_hash();
    splined_terrain();
    protect_and_erosion();
    trails();
    puts("island: all ok");
    free(blob);
    return 0;
}
