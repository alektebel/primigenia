/* Island desc (docs/plans/island-realism.md F0): CRC, parse errors, limits, round trip, and the parity gate:
 * the desc made from layout 1 by tools/island/from_layout.mjs + pack.mjs generates the same terrain hash as --layout 1.
 *   test_island BLOB.isl [--heavy]      (--heavy adds n = 1536) */
#include "cpore/island.h"
#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* terrain_cli hash --layout 1 --n N, recorded before the evaluator was split out of layout_height (seed 1, defaults). */
static const struct { int n; uint64_t hash; } L1_GOLD[] = {
    {256, 0xf2a5f6596b9e205aull}, {512, 0xdc35612d7e211f85ull}, {1536, 0xf45b85dd9c35633aull},
};
static const uint64_t L234_256[3] = {0x58864d88ccaa919aull, 0xe4f39102912a5a86ull, 0x25abc58f831502c1ull};

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

static int gen(const CpTerrainParams *p, const CpIslandDesc *d, uint64_t *hash)
{
    Fixture f = fixture(p->n); int rc;
    rc = d ? cp_terrain_generate_desc(p, d, &f.t, &f.w, NULL, NULL) : cp_terrain_generate(p, &f.t, &f.w, NULL, NULL);
    if (rc == CP_TERR_OK) { f.t.n = p->n; f.t.size_m = p->size_m; *hash = cp_terrain_hash(&f.t); }
    release(&f);
    return rc;
}
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
        printf("island: n %4d  layout 1 %016" PRIx64 "  desc %016" PRIx64 "%s\n", L1_GOLD[i].n, a, b, a == b ? "  identical" : "  DIFFERENT");
        assert(a == L1_GOLD[i].hash);   /* the evaluator split did not move layout 1 */
        assert(b == a);                 /* the gate */
    }
    /* the desc path does not read p->layout, and the other layouts did not move */
    params_for(&p, 1, 256); p.layout = 0.f;
    assert(gen(&p, &D, &b) == CP_TERR_OK && b == L1_GOLD[0].hash);
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
    puts("island: all ok");
    free(blob);
    return 0;
}
