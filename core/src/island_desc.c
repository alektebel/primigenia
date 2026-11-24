/* cpore - island description: blob parse, pack, hash, CRC and the evaluator's float cache (island.h).
 * No malloc, libc only. The float cache converts each integer with ONE division by a power of ten, so it is
 * exact for whole design units and correctly rounded otherwise (the same on every IEEE-754 platform). */
#include "cpore/island.h"

#include <string.h>

#define META_I32 22
#define COUNT_I32 8
#define INT_LIM 16777216   /* 2^24: every stored integer converts to float exactly */

uint32_t cp_island_crc32(const uint8_t *p, size_t n)
{
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < n; i++) {
        c ^= p[i];
        for (int k = 0; k < 8; k++) c = (c >> 1) ^ (0xEDB88320u & (0u - (c & 1u)));
    }
    return ~c;
}

/* CRC over the whole blob except the CRC field itself (bytes 12..15). */
static uint32_t blob_crc(const uint8_t *b, size_t len)
{
    uint32_t x = 0xFFFFFFFFu;
    for (size_t i = 0; i < len; i++) {
        if (i >= 12 && i < CP_ISL_HEADER_BYTES) continue;
        x ^= b[i];
        for (int k = 0; k < 8; k++) x = (x >> 1) ^ (0xEDB88320u & (0u - (x & 1u)));
    }
    return ~x;
}

/* ---- serialisation: one walk used for pack (store) and hash (FNV only) ---------------------------------------- */
typedef struct { uint8_t *buf; size_t cap, pos; uint64_t fnv; int store; } Wr;

static void w8(Wr *w, uint8_t b)
{
    w->fnv ^= b; w->fnv *= 1099511628211ull;
    if (w->store && w->pos < w->cap) w->buf[w->pos] = b;
    w->pos++;
}
static void w32(Wr *w, int32_t v)
{
    uint32_t u = (uint32_t)v;
    for (int i = 0; i < 4; i++) w8(w, (uint8_t)(u >> (8 * i)));
}
static void wstr(Wr *w, const char *s, int n)
{
    for (int i = 0; i < n; i++) w8(w, (uint8_t)s[i]);
}

static void walk(const CpIslandDesc *d, Wr *w)
{
    w32(w, d->size_dm); w32(w, d->island_radius_dm); w32(w, d->n); w32(w, d->scale_pm);
    w32(w, d->wind_mdeg); w32(w, d->wind_cms);
    w32(w, d->reef_x_pm); w32(w, d->reef_y_pm); w32(w, d->cliff_x_pm); w32(w, d->cliff_y_pm);
    w32(w, d->nest_r_dm); w32(w, d->nest_floor_cm); w32(w, d->lake_x_dm); w32(w, d->lake_y_dm);
    w32(w, d->lake_r_dm); w32(w, d->lake_depth_cm); w32(w, d->stream_iters); w32(w, d->droplets);
    w32(w, d->clim_scale_h_pm); w32(w, d->clim_scale_z_pm); w32(w, d->clim_t_sea_cC); w32(w, d->clim_lapse_cK_per_km);
    wstr(w, d->id, CP_ISL_NAME);
    w32(w, d->nfeat); w32(w, d->npt); w32(w, d->ntrail); w32(w, d->ntrail_pt);
    w32(w, d->nregion); w32(w, d->nregion_pt); w32(w, d->nmark); w32(w, d->nmask);
    for (int i = 0; i < d->nfeat; i++) {
        const CpIslandFeature *f = &d->feat[i];
        w32(w, f->kind); w32(w, f->x_dm); w32(w, f->y_dm); w32(w, f->across_dm); w32(w, f->along_dm);
        w32(w, f->h_cm); w32(w, f->k); w32(w, f->pt0); w32(w, f->npts); w32(w, f->flags);
        wstr(w, f->name, CP_ISL_NAME);
    }
    for (int i = 0; i < d->npt; i++) { w32(w, d->pt[i].x_dm); w32(w, d->pt[i].y_dm); w32(w, d->pt[i].hw_dm); w32(w, d->pt[i].h_cm); }
    for (int i = 0; i < d->ntrail; i++) { w32(w, d->trail[i].pt0); w32(w, d->trail[i].npts); wstr(w, d->trail[i].kind, 16); }
    for (int i = 0; i < d->ntrail_pt; i++) { w32(w, d->trail_pt[i][0]); w32(w, d->trail_pt[i][1]); }
    for (int i = 0; i < d->nregion; i++) {
        const CpIslandRegion *r = &d->region[i];
        w32(w, r->gate); w32(w, r->w_dm); w32(w, r->pt0); w32(w, r->npts);
        wstr(w, r->name, CP_ISL_NAME); wstr(w, r->kind, 16); wstr(w, r->biome, 16);
    }
    for (int i = 0; i < d->nregion_pt; i++) { w32(w, d->region_pt[i][0]); w32(w, d->region_pt[i][1]); }
    for (int i = 0; i < d->nmark; i++) {
        w32(w, d->mark[i].x_dm); w32(w, d->mark[i].y_dm); wstr(w, d->mark[i].name, CP_ISL_NAME); wstr(w, d->mark[i].kind, 16);
    }
    for (int m = 0; m < d->nmask; m++)
        for (int i = 0; i < CP_ISL_MASK_RES * CP_ISL_MASK_RES; i++) w8(w, d->mask[m][i]);
}

uint64_t cp_island_hash(const CpIslandDesc *d)
{
    Wr w; w.buf = NULL; w.cap = 0; w.pos = 0; w.fnv = 14695981039346656037ull; w.store = 0;
    if (!d) return 0;
    walk(d, &w);
    return w.fnv;
}

size_t cp_island_pack(const CpIslandDesc *d, uint8_t *buf, size_t cap)
{
    Wr w; size_t body; uint32_t crc;
    if (!d || !buf || cap < CP_ISL_HEADER_BYTES) return 0;
    w.buf = buf + CP_ISL_HEADER_BYTES; w.cap = cap - CP_ISL_HEADER_BYTES; w.pos = 0; w.fnv = 14695981039346656037ull; w.store = 1;
    walk(d, &w);
    if (w.pos > w.cap) return 0;
    body = w.pos;
    memcpy(buf, "ISL1", 4);
    buf[4] = CP_ISL_FORMAT; buf[5] = 0; buf[6] = 0; buf[7] = 0;
    for (int i = 0; i < 4; i++) buf[8 + i] = (uint8_t)((uint32_t)body >> (8 * i));
    crc = blob_crc(buf, CP_ISL_HEADER_BYTES + body);
    for (int i = 0; i < 4; i++) buf[12 + i] = (uint8_t)(crc >> (8 * i));
    return CP_ISL_HEADER_BYTES + body;
}

/* ---- parse ---------------------------------------------------------------------------------------------------- */
typedef struct { const uint8_t *p; size_t len, pos; int err; } Rd;

static int32_t r32(Rd *r)
{
    uint32_t u = 0;
    if (r->err) return 0;
    if (r->pos + 4 > r->len) { r->err = CP_TERR_ERR_ISL_TRUNC; return 0; }
    for (int i = 0; i < 4; i++) u |= (uint32_t)r->p[r->pos + (size_t)i] << (8 * i);
    r->pos += 4;
    return (int32_t)u;
}
static uint8_t r8(Rd *r)
{
    if (r->err) return 0;
    if (r->pos + 1 > r->len) { r->err = CP_TERR_ERR_ISL_TRUNC; return 0; }
    return r->p[r->pos++];
}
/* A canonical string: NUL-terminated inside the field and zero-padded after, so pack(parse(b)) == b. */
static void rstr(Rd *r, char *dst, int n)
{
    int z = 0;
    if (r->err) return;
    if (r->pos + (size_t)n > r->len) { r->err = CP_TERR_ERR_ISL_TRUNC; return; }
    for (int i = 0; i < n; i++) {
        char c = (char)r->p[r->pos + (size_t)i];
        if (z && c != 0) { r->err = CP_TERR_ERR_ISL_FIELD; return; }
        if (c == 0) z = 1; else if ((unsigned char)c < 32 || (unsigned char)c > 126) { r->err = CP_TERR_ERR_ISL_FIELD; return; }
        dst[i] = c;
    }
    if (!z) r->err = CP_TERR_ERR_ISL_FIELD;
    r->pos += (size_t)n;
}

static int in_int(int32_t v) { return v >= -INT_LIM && v <= INT_LIM; }
static int bad(Rd *r, int cond) { if (cond && !r->err) r->err = CP_TERR_ERR_ISL_FIELD; return cond; }

static float f10(int32_t v) { return (float)v / 10.f; }
static float f100(int32_t v) { return (float)v / 100.f; }
static float f1000(int32_t v) { return (float)v / 1000.f; }

int cp_island_prepare(CpIslandDesc *d)
{
    int ne = 0;
    if (!d) return CP_TERR_ERR_NULL;
    d->scale = f1000(d->scale_pm);
    d->nest_r = f10(d->nest_r_dm);
    d->reef_x = f1000(d->reef_x_pm); d->reef_y = f1000(d->reef_y_pm);
    d->cliff_x = f1000(d->cliff_x_pm); d->cliff_y = f1000(d->cliff_y_pm);
    for (int i = 0; i < d->nfeat; i++) {
        const CpIslandFeature *f = &d->feat[i];
        if (f->kind == CP_ISL_RANGE || f->kind == CP_ISL_CHANNEL) {
            for (int s = 0; s + 1 < f->npts; s++) {
                const CpIslandPoint *a = &d->pt[f->pt0 + s], *b = a + 1;
                CpIslandEval *e = &d->eval[ne++];
                e->kind = f->kind;
                e->x0 = f10(a->x_dm); e->y0 = f10(a->y_dm); e->x1 = f10(b->x_dm); e->y1 = f10(b->y_dm);
                e->w = f10(a->hw_dm);
                e->h = f100(a->h_cm); e->h2 = f100(b->h_cm);
                if (f->kind == CP_ISL_RANGE) { e->w2 = 0.f; e->k = f1000(f->k); }
                else { e->w2 = f10(f->along_dm); e->k = ((f->flags & CP_ISL_F_SEA) && s + 2 == f->npts) ? 1.f : 0.f; }
            }
        } else {
            CpIslandEval *e = &d->eval[ne++];
            e->kind = f->kind;
            e->x0 = f10(f->x_dm); e->y0 = f10(f->y_dm); e->x1 = 0.f; e->y1 = 0.f;
            e->w = f10(f->across_dm); e->w2 = f10(f->along_dm);
            e->h = f100(f->h_cm); e->h2 = 0.f; e->k = f1000(f->k);
            if (f->kind == CP_ISL_RING) { e->x0 = 0.f; e->y0 = 0.f; }
            if (f->kind == CP_ISL_CONE || f->kind == CP_ISL_BADLANDS) e->w2 = 0.f;
            if (f->kind != CP_ISL_MASSIF && f->kind != CP_ISL_TERRACE && f->kind != CP_ISL_BADLANDS) e->k = 0.f;
        }
    }
    d->neval = ne;
    return CP_TERR_OK;
}

static int validate_features(CpIslandDesc *d, Rd *r)
{
    for (int i = 0; i < d->nfeat; i++) {
        const CpIslandFeature *f = &d->feat[i];
        int poly = f->kind == CP_ISL_RANGE || f->kind == CP_ISL_CHANNEL;
        if (bad(r, f->kind < CP_ISL_MASSIF || f->kind > CP_ISL_CONE)) return r->err;
        if (bad(r, !in_int(f->x_dm) || !in_int(f->y_dm) || !in_int(f->across_dm) || !in_int(f->along_dm) || !in_int(f->h_cm) || !in_int(f->k))) return r->err;
        if (bad(r, (f->flags & ~(CP_ISL_F_SEA | CP_ISL_F_RIVER | CP_ISL_F_SPLINE)) != 0)) return r->err;
        if (bad(r, (f->flags & CP_ISL_F_SPLINE) != 0)) return r->err;               /* F1 */
        if (bad(r, (f->flags & CP_ISL_F_SEA) && f->kind != CP_ISL_CHANNEL)) return r->err;
        if (poly) {
            if (bad(r, f->npts < 2 || f->pt0 < 0 || f->pt0 > d->npt || f->npts > d->npt - f->pt0)) return r->err;
            for (int s = 0; s < f->npts; s++) {
                const CpIslandPoint *q = &d->pt[f->pt0 + s];
                if (bad(r, !in_int(q->x_dm) || !in_int(q->y_dm) || !in_int(q->hw_dm) || !in_int(q->h_cm) || q->hw_dm <= 0)) return r->err;
            }
            if (f->kind == CP_ISL_CHANNEL && bad(r, f->along_dm <= 0)) return r->err;
        } else {
            if (bad(r, f->npts != 0 || f->pt0 != 0)) return r->err;
            if (bad(r, f->across_dm <= 0)) return r->err;
            if ((f->kind == CP_ISL_MASSIF || f->kind == CP_ISL_RING || f->kind == CP_ISL_PLATEAU || f->kind == CP_ISL_TERRACE || f->kind == CP_ISL_ISLET) &&
                bad(r, f->along_dm <= 0)) return r->err;
            if (f->kind == CP_ISL_TERRACE && bad(r, f->h_cm <= 0)) return r->err;
        }
    }
    return 0;
}

int cp_island_parse(const uint8_t *blob, size_t len, CpIslandDesc *out)
{
    Rd r; uint32_t body, crc, c; int32_t v[COUNT_I32];
    if (!blob || !out) return CP_TERR_ERR_NULL;
    if (len < CP_ISL_HEADER_BYTES) return CP_TERR_ERR_ISL_TRUNC;
    if (memcmp(blob, "ISL1", 4) != 0) return CP_TERR_ERR_ISL_MAGIC;
    if (blob[4] != CP_ISL_FORMAT || blob[5] != 0 || blob[6] != 0 || blob[7] != 0) return CP_TERR_ERR_ISL_VERSION;
    body = (uint32_t)blob[8] | (uint32_t)blob[9] << 8 | (uint32_t)blob[10] << 16 | (uint32_t)blob[11] << 24;
    if ((size_t)body != len - CP_ISL_HEADER_BYTES) return CP_TERR_ERR_ISL_TRUNC;
    crc = (uint32_t)blob[12] | (uint32_t)blob[13] << 8 | (uint32_t)blob[14] << 16 | (uint32_t)blob[15] << 24;
    c = blob_crc(blob, len);
    if (c != crc) return CP_TERR_ERR_ISL_CRC;

    memset(out, 0, sizeof *out);
    memset(out->mask, 128, sizeof out->mask);
    r.p = blob + CP_ISL_HEADER_BYTES; r.len = body; r.pos = 0; r.err = 0;
    out->size_dm = r32(&r); out->island_radius_dm = r32(&r); out->n = r32(&r); out->scale_pm = r32(&r);
    out->wind_mdeg = r32(&r); out->wind_cms = r32(&r);
    out->reef_x_pm = r32(&r); out->reef_y_pm = r32(&r); out->cliff_x_pm = r32(&r); out->cliff_y_pm = r32(&r);
    out->nest_r_dm = r32(&r); out->nest_floor_cm = r32(&r); out->lake_x_dm = r32(&r); out->lake_y_dm = r32(&r);
    out->lake_r_dm = r32(&r); out->lake_depth_cm = r32(&r); out->stream_iters = r32(&r); out->droplets = r32(&r);
    out->clim_scale_h_pm = r32(&r); out->clim_scale_z_pm = r32(&r); out->clim_t_sea_cC = r32(&r); out->clim_lapse_cK_per_km = r32(&r);
    rstr(&r, out->id, CP_ISL_NAME);
    for (int i = 0; i < COUNT_I32; i++) v[i] = r32(&r);
    if (r.err) return r.err;
    if (v[0] < 0 || v[0] > CP_ISL_MAX_FEAT || v[1] < 0 || v[1] > CP_ISL_MAX_PT || v[2] < 0 || v[2] > CP_ISL_MAX_TRAIL ||
        v[3] < 0 || v[3] > CP_ISL_MAX_TRAIL_PT || v[4] < 0 || v[4] > CP_ISL_MAX_REGION || v[5] < 0 || v[5] > CP_ISL_MAX_REGION_PT ||
        v[6] < 0 || v[6] > CP_ISL_MAX_MARK || v[7] < 0 || v[7] > CP_ISL_MAX_MASK) return CP_TERR_ERR_ISL_LIMIT;
    out->nfeat = v[0]; out->npt = v[1]; out->ntrail = v[2]; out->ntrail_pt = v[3];
    out->nregion = v[4]; out->nregion_pt = v[5]; out->nmark = v[6]; out->nmask = v[7];

    /* bounds on the body size from the counts, before any record is read */
    {   size_t need = (size_t)out->nfeat * (40 + CP_ISL_NAME) + (size_t)out->npt * 16 + (size_t)out->ntrail * 24 + (size_t)out->ntrail_pt * 8 +
                      (size_t)out->nregion * (16 + CP_ISL_NAME + 32) + (size_t)out->nregion_pt * 8 + (size_t)out->nmark * (8 + CP_ISL_NAME + 16) +
                      (size_t)out->nmask * CP_ISL_MASK_RES * CP_ISL_MASK_RES;
        if (r.pos + need != r.len) return CP_TERR_ERR_ISL_TRUNC;
    }
    for (int i = 0; i < out->nfeat; i++) {
        CpIslandFeature *f = &out->feat[i];
        f->kind = r32(&r); f->x_dm = r32(&r); f->y_dm = r32(&r); f->across_dm = r32(&r); f->along_dm = r32(&r);
        f->h_cm = r32(&r); f->k = r32(&r); f->pt0 = r32(&r); f->npts = r32(&r); f->flags = r32(&r);
        rstr(&r, f->name, CP_ISL_NAME);
    }
    for (int i = 0; i < out->npt; i++) { CpIslandPoint *q = &out->pt[i]; q->x_dm = r32(&r); q->y_dm = r32(&r); q->hw_dm = r32(&r); q->h_cm = r32(&r); }
    for (int i = 0; i < out->ntrail; i++) { out->trail[i].pt0 = r32(&r); out->trail[i].npts = r32(&r); rstr(&r, out->trail[i].kind, 16); }
    for (int i = 0; i < out->ntrail_pt; i++) { out->trail_pt[i][0] = r32(&r); out->trail_pt[i][1] = r32(&r); }
    for (int i = 0; i < out->nregion; i++) {
        CpIslandRegion *g = &out->region[i];
        g->gate = r32(&r); g->w_dm = r32(&r); g->pt0 = r32(&r); g->npts = r32(&r);
        rstr(&r, g->name, CP_ISL_NAME); rstr(&r, g->kind, 16); rstr(&r, g->biome, 16);
    }
    for (int i = 0; i < out->nregion_pt; i++) { out->region_pt[i][0] = r32(&r); out->region_pt[i][1] = r32(&r); }
    for (int i = 0; i < out->nmark; i++) { out->mark[i].x_dm = r32(&r); out->mark[i].y_dm = r32(&r); rstr(&r, out->mark[i].name, CP_ISL_NAME); rstr(&r, out->mark[i].kind, 16); }
    for (int m = 0; m < out->nmask; m++) for (int i = 0; i < CP_ISL_MASK_RES * CP_ISL_MASK_RES; i++) out->mask[m][i] = r8(&r);
    if (r.err) return r.err;
    if (r.pos != r.len) return CP_TERR_ERR_ISL_TRUNC;

    /* meta */
    if (bad(&r, out->size_dm < 160 || out->size_dm > 1000000 || out->island_radius_dm < 10 || out->island_radius_dm > 4000000)) return r.err;
    if (bad(&r, out->n < CP_TERRAIN_N_MIN || out->n > CP_TERRAIN_N_MAX)) return r.err;
    if (bad(&r, out->scale_pm < 100 || out->scale_pm > 10000)) return r.err;
    if (bad(&r, out->wind_mdeg < 0 || out->wind_mdeg >= 360000 || out->wind_cms < 0 || out->wind_cms > 10000)) return r.err;
    if (bad(&r, out->reef_x_pm < -1000 || out->reef_x_pm > 1000 || out->reef_y_pm < -1000 || out->reef_y_pm > 1000 ||
               out->cliff_x_pm < -1000 || out->cliff_x_pm > 1000 || out->cliff_y_pm < -1000 || out->cliff_y_pm > 1000)) return r.err;
    if (bad(&r, out->nest_r_dm < 10 || out->nest_r_dm > out->size_dm || !in_int(out->nest_floor_cm) || out->nest_floor_cm < -800000 || out->nest_floor_cm > 800000)) return r.err;
    if (bad(&r, !in_int(out->lake_x_dm) || !in_int(out->lake_y_dm) || out->lake_r_dm < 10 || out->lake_r_dm > out->size_dm ||
               out->lake_depth_cm < 0 || out->lake_depth_cm > 200000)) return r.err;
    if (bad(&r, out->lake_x_dm < -out->size_dm || out->lake_x_dm > out->size_dm || out->lake_y_dm < -out->size_dm || out->lake_y_dm > out->size_dm)) return r.err;
    if (bad(&r, out->stream_iters < 0 || out->stream_iters > 256 || out->droplets < 0 || out->droplets > 2000000)) return r.err;
    if (validate_features(out, &r)) return r.err;
    for (int i = 0; i < out->ntrail; i++) {
        const CpIslandTrail *t = &out->trail[i];
        if (bad(&r, t->npts < 2 || t->pt0 < 0 || t->pt0 > out->ntrail_pt || t->npts > out->ntrail_pt - t->pt0)) return r.err;
    }
    for (int i = 0; i < out->nregion; i++) {
        const CpIslandRegion *g = &out->region[i];
        if (bad(&r, g->gate < 0 || g->gate > 2 || g->w_dm < 0 || !in_int(g->w_dm) || g->npts < 1 || g->pt0 < 0 || g->pt0 > out->nregion_pt || g->npts > out->nregion_pt - g->pt0)) return r.err;
    }
    for (int i = 0; i < out->ntrail_pt; i++) if (bad(&r, !in_int(out->trail_pt[i][0]) || !in_int(out->trail_pt[i][1]))) return r.err;
    for (int i = 0; i < out->nregion_pt; i++) if (bad(&r, !in_int(out->region_pt[i][0]) || !in_int(out->region_pt[i][1]))) return r.err;
    for (int i = 0; i < out->nmark; i++) if (bad(&r, !in_int(out->mark[i].x_dm) || !in_int(out->mark[i].y_dm))) return r.err;
    return cp_island_prepare(out);
}
