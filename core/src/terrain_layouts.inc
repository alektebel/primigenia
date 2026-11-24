/* Island layouts (DESIGN A83). Included by terrain.c; not a public header.
 *
 * CpTerrainParams.layout = 0 keeps the v4 ring island byte for byte. 1..4 replace base_height() with a layout table:
 * a list of terrain features (massifs, ranges, a nest rim, plateaus, terrace zones, badlands, channels, islets) plus
 * descriptive meta (regions, routes, gates, landmarks) that the design tools draw on the maps. Erosion, rivers, caves
 * and materials downstream are the unchanged pipeline. The nest valley is always at the origin.
 * Same float discipline as the rest: + - * / sqrtf only. Directions come from degrees through a polynomial. */

enum { LF_MASSIF = 1, LF_RANGE, LF_RING, LF_PLATEAU, LF_TERRACE, LF_BADLANDS, LF_CHANNEL, LF_ISLET, LF_CONE };

/* Field use per kind:
 *  MASSIF   (x0,y0) centre, w across, w2 along, k axis angle deg, h height
 *  RANGE    (x0,y0)->(x1,y1) crest line, w half width, h height at start, h2 at end, k ruggedness 0..1
 *  RING     origin; w radius, w2 half width, h height  (the nest rim; channels cut it)
 *  PLATEAU  (x0,y0) centre, w flat radius, w2 cliff width, h top altitude
 *  TERRACE  (x0,y0) centre, w full-effect radius, w2 feather, h tread step (m), k strength
 *  BADLANDS (x0,y0) centre, w radius, h relief amplitude, k frequency scale
 *  CHANNEL  (x0,y0)->(x1,y1) floor line, w half floor, w2 wall width, h floor altitude at start, h2 at end,
 *           k 1 = reaches the sea (the coast there is a beach, not a cliff)
 *  ISLET    (x0,y0) centre, w radius, h peak altitude, w2 bay radius cut in the main coast
 *  CONE     (x0,y0) centre, w reach, h height at the centre (a tilted island surface) */
typedef struct { int kind; float x0, y0, x1, y1, w, w2, h, h2, k; } LFeat;

/* Meta for the maps. Regions are polylines with a width (one point = a disc). gate: 0 open from the start,
 * 1 needs climbing, 2 needs swimming or gliding. */
typedef struct { const char *name, *kind; int gate, n; float w; float p[6][2]; } LRegion;
typedef struct { const char *name, *kind; int n; float p[7][2]; } LRoute;
typedef struct { const char *name, *kind; float x, y; } LMark;

typedef struct {
    const char *id, *title;
    float nest_r;                 /* flat floor radius of the nest valley */
    int stream, droplets;         /* recommended erosion (0 = the default); stepped tiers need a light hand */
    int nf, nreg, nroute, nmark;
    const LFeat *f; const LRegion *reg; const LRoute *route; const LMark *mark;
} Layout;

#define NEST_RIM(R0, W2, H) {LF_RING, 0, 0, 0, 0, R0, W2, H, 0, 0}
#define MASSIF(X, Y, A, L, ANG, H) {LF_MASSIF, X, Y, 0, 0, A, L, H, 0, ANG}
#define RANGE(X0, Y0, X1, Y1, HW, H0, H1, K) {LF_RANGE, X0, Y0, X1, Y1, HW, 0, H0, H1, K}
#define PLATEAU(X, Y, R, CLIFF, TOP) {LF_PLATEAU, X, Y, 0, 0, R, CLIFF, TOP, 0, 0}
#define TERRACE(X, Y, R, FEATHER, STEP, K) {LF_TERRACE, X, Y, 0, 0, R, FEATHER, STEP, 0, K}
#define BADLANDS(X, Y, R, AMP, FREQ) {LF_BADLANDS, X, Y, 0, 0, R, 0, AMP, 0, FREQ}
#define CHANNEL(X0, Y0, X1, Y1, HW, WALL, F0, F1, SEA) {LF_CHANNEL, X0, Y0, X1, Y1, HW, WALL, F0, F1, SEA}
#define ISLET(X, Y, R, TOP, BAY) {LF_ISLET, X, Y, 0, 0, R, BAY, TOP, 0, 0}
#define CONE(X, Y, REACH, H) {LF_CONE, X, Y, 0, 0, REACH, 0, H, 0, 0}

/* ---- 1. Star massif: radial valleys around one central massif ---------------------------------------------- */
static const LFeat L1_F[] = {
    MASSIF(-300, -240, 430, 520, 20, 640), MASSIF(-520, -430, 230, 260, 60, 520),
    RANGE(-300, -240,   44,  961, 250, 330,  90, 0.8f),   /* S spur, west rim of the nest wedge */
    RANGE(-300, -240, -1311,  495, 270, 300,  80, 0.8f),
    RANGE(-300, -240, -1336, -939, 270, 350, 100, 0.8f),
    RANGE(-300, -240,    2, -1453, 270, 330,  90, 0.8f),
    RANGE(-300, -240,  993, -376, 250, 320, 110, 0.8f),   /* E spur, north rim of the nest wedge */
    NEST_RIM(330, 130, 150),
    PLATEAU(-1060, -560, 270, 100, 430),                  /* Mesa: cliff plateau on the NW spur end */
    TERRACE(780, 380, 470, 260, 24, 0.9f),                 /* delta terraces */
    TERRACE(-330, 720, 300, 200, 20, 0.6f),
    BADLANDS(-560, 1000, 400, 130, 1.f),
    CHANNEL(0, 0, 450, 420, 110, 260, 38, 26, 0),         /* exit 1: river valley to the SE coast */
    CHANNEL(450, 420, 950, 820, 110, 280, 26, 12, 0),
    CHANNEL(950, 820, 1380, 1020, 90, 220, 12, 0, 1),
    CHANNEL(0, 0, 250, -330, 70, 200, 42, 96, 0),         /* exit 2: north pass into the forest vale */
    CHANNEL(250, -330, 560, -690, 110, 260, 96, 70, 0),
    CHANNEL(560, -690, 800, -1100, 120, 280, 70, 36, 0),
    CHANNEL(800, -1100, 1010, -1350, 100, 240, 36, 0, 1),
    CHANNEL(0, 0, -200, 260, 70, 200, 42, 100, 0),        /* exit 3: south pass to the canyon head */
    CHANNEL(-200, 260, -430, 400, 60, 160, 100, 80, 0),
    CHANNEL(-430, 400, -600, 760, 42, 100, 80, 52, 0),    /* the canyon */
    CHANNEL(-600, 760, -740, 1180, 42, 100, 52, 30, 0),
    CHANNEL(-740, 1180, -840, 1480, 60, 160, 30, 0, 1),
    CHANNEL(0, 0, -300, 100, 60, 180, 42, 108, 0),        /* exit 4: west saddle to the mesa foot */
    CHANNEL(-300, 100, -760, 130, 90, 240, 108, 70, 0),
    CHANNEL(-760, 130, -1500, -40, 100, 260, 70, 0, 1),
    ISLET(1180, -1060, 160, 170, 400),
};
static const LRegion L1_R[] = {
    {"Nest valley", "nest", 0, 1, 0, {{0, 0}}},
    {"Forest vale", "forest", 0, 4, 380, {{300, -380}, {560, -690}, {800, -1000}, {950, -1230}}},
    {"Delta and terraces", "coast", 0, 2, 380, {{650, 350}, {950, 800}}},
    {"Canyon badlands", "canyon", 0, 3, 300, {{-450, 400}, {-640, 800}, {-760, 1200}}},
    {"Mesa", "plateau", 1, 1, 270, {{-1060, -560}}},
    {"Islet", "islet", 2, 1, 160, {{1180, -1060}}},
};
static const LRoute L1_T[] = {
    {"Exit 1: river valley", "exit", 4, {{0, 0}, {450, 420}, {950, 820}, {1380, 1020}}},
    {"Exit 2: north pass", "exit", 4, {{0, 0}, {250, -330}, {560, -690}, {850, -1150}}},
    {"Exit 3: south pass", "exit", 4, {{0, 0}, {-200, 260}, {-600, 760}, {-840, 1480}}},
    {"Exit 4: west saddle", "exit", 3, {{0, 0}, {-300, 100}, {-760, 130}}},
};
static const LMark L1_M[] = {
    {"Crown Horn", "peak", -300, -240}, {"Meteor crater", "crater", -90, 40},
    {"Split Spire", "spire", -640, 920}, {"Great tree", "tree", 620, -760},
    {"Sea arch", "arch", 1180, -1060}, {"Mesa", "plateau", -1060, -560},
};

/* ---- 2. Great rift: a long river corridor from the nest to the coast, a gorge in the middle ---------------- */
static const LFeat L2_F[] = {
    MASSIF(-1000, 0, 420, 520, 90, 560),                  /* headwall behind the nest */
    RANGE(-800, -540, 1100, -620, 280, 400, 300, 0.7f),   /* north range */
    RANGE(-900, 540, 1000, 580, 280, 380, 300, 0.7f),     /* south range */
    RANGE(820, -560, 840, 560, 230, 330, 330, 0.9f),      /* cross-bar the river cuts: the gorge */
    NEST_RIM(330, 120, 140),
    PLATEAU(-900, -800, 250, 60, 480),                   /* Cloud mesa, gated */
    TERRACE(150, -1000, 520, 260, 26, 0.9f),              /* north uplands */
    TERRACE(1150, 450, 340, 200, 18, 0.7f),
    BADLANDS(120, 1040, 470, 120, 1.f),                   /* south basin */
    CHANNEL(0, 0, 350, 30, 150, 420, 38, 34, 0),          /* the corridor */
    CHANNEL(350, 30, 640, -10, 150, 420, 34, 28, 0),
    CHANNEL(640, -10, 1060, 20, 42, 90, 28, 12, 0),       /* the gorge */
    CHANNEL(1060, 20, 1320, 120, 120, 320, 12, 6, 0),
    CHANNEL(1320, 120, 1560, 170, 110, 300, 6, 0, 1),
    CHANNEL(0, 0, -60, -330, 70, 200, 42, 118, 0),        /* exit N: pass to the uplands */
    CHANNEL(-60, -330, 150, -640, 90, 240, 118, 100, 0),
    CHANNEL(150, -640, 420, -960, 100, 260, 100, 60, 0),
    CHANNEL(0, 0, -50, 330, 70, 200, 42, 112, 0),         /* exit S: pass to the basin */
    CHANNEL(-50, 330, 0, 700, 100, 260, 112, 70, 0),
    CHANNEL(0, 0, -300, -40, 70, 200, 42, 108, 0),        /* exit W: col to the headwall shelf */
    CHANNEL(-300, -40, -620, -200, 80, 220, 108, 120, 0),
    ISLET(1020, 1130, 150, 160, 400),
};
static const LRegion L2_R[] = {
    {"Nest valley", "nest", 0, 1, 0, {{0, 0}}},
    {"Forest corridor", "forest", 0, 3, 330, {{250, 20}, {450, 10}, {620, -20}}},
    {"North terraces", "terraces", 0, 1, 520, {{150, -1000}}},
    {"South badlands", "badlands", 0, 1, 470, {{120, 1040}}},
    {"Rift gorge", "canyon", 0, 2, 120, {{760, 5}, {1060, 20}}},
    {"Cloud mesa", "plateau", 1, 1, 250, {{-900, -800}}},
    {"Islet", "islet", 2, 1, 150, {{1020, 1130}}},
};
static const LRoute L2_T[] = {
    {"River corridor", "exit", 5, {{0, 0}, {350, 30}, {1060, 20}, {1320, 120}, {1560, 170}}},
    {"North pass", "exit", 4, {{0, 0}, {-60, -330}, {150, -640}, {420, -960}}},
    {"South pass", "exit", 3, {{0, 0}, {-50, 330}, {0, 700}}},
    {"West col", "exit", 3, {{0, 0}, {-300, -40}, {-620, -200}}},
};
static const LMark L2_M[] = {
    {"Anvil", "peak", -1000, 0}, {"Meteor crater", "crater", -90, 40},
    {"Gate Rock", "spire", 640, -60}, {"Great tree", "tree", 400, 180},
    {"Sea arch", "arch", 1020, 1130}, {"Cloud mesa", "plateau", -900, -800},
};

/* ---- 3. Stepped plateau island: tiers down from a high plateau, the nest sunk in a pit ---------------------- */
static const LFeat L3_F[] = {
    CONE(420, -380, 1900, 330),
    PLATEAU(430, -420, 230, 60, 480),                    /* Sky terrace, gated */
    TERRACE(430, -380, 1900, 500, 44, 0.92f),            /* the whole island steps down in treads */
    RANGE(-700, -400, -300, -950, 160, 120, 60, 0.9f),   /* low buttress ridges between the tiers */
    RANGE(900, 0, 1150, 700, 150, 110, 40, 0.9f),
    BADLANDS(-700, 450, 350, 100, 1.f),
    CHANNEL(0, 0, 180, 120, 60, 130, 42, 60, 0),          /* exit 1: ramp SE into the stair canyon */
    CHANNEL(180, 120, 520, 220, 80, 200, 60, 38, 0),
    CHANNEL(300, -300, 620, 40, 52, 90, 150, 105, 0),     /* the stair canyon */
    CHANNEL(620, 40, 880, 420, 50, 90, 105, 66, 0),
    CHANNEL(880, 420, 1130, 800, 50, 100, 66, 34, 0),
    CHANNEL(1130, 800, 1400, 1130, 70, 160, 34, 0, 1),
    CHANNEL(520, 220, 620, 40, 80, 200, 38, 105, 0),
    CHANNEL(0, 0, -160, -60, 60, 130, 42, 66, 0),         /* exit 2: ramp W down to the forest tier */
    CHANNEL(-160, -60, -520, -110, 100, 220, 66, 60, 0),
    CHANNEL(0, 0, -20, -180, 60, 130, 42, 104, 0),        /* exit 3: ramp N up to the mid tiers */
    CHANNEL(-20, -180, 20, -480, 100, 220, 104, 110, 0),
    CHANNEL(0, 0, -30, 170, 60, 130, 42, 70, 0),          /* exit 4: ramp S to the red steps */
    CHANNEL(-30, 170, -200, 520, 100, 220, 70, 62, 0),
    ISLET(-1180, 1010, 150, 150, 400),
};
static const LRegion L3_R[] = {
    {"Nest valley", "nest", 0, 1, 0, {{0, 0}}},
    {"Forest tier", "forest", 0, 5, 320, {{-520, -110}, {-700, -500}, {-450, -900}, {0, -1180}, {560, -1150}}},
    {"Stair canyon", "canyon", 0, 4, 200, {{620, 40}, {880, 420}, {1130, 800}, {1330, 1060}}},
    {"Red steps", "badlands", 0, 1, 360, {{-700, 450}}},
    {"Sky terrace", "plateau", 1, 1, 220, {{430, -420}}},
    {"Islet", "islet", 2, 1, 150, {{-1180, 1010}}},
};
static const LRoute L3_T[] = {
    {"Exit 1: SE ramp", "exit", 4, {{0, 0}, {180, 120}, {520, 220}, {620, 40}}},
    {"Exit 2: west ramp", "exit", 3, {{0, 0}, {-160, -60}, {-520, -110}}},
    {"Exit 3: north ramp", "exit", 3, {{0, 0}, {-20, -180}, {20, -480}}},
    {"Exit 4: south ramp", "exit", 3, {{0, 0}, {-30, 170}, {-200, 520}}},
};
static const LMark L3_M[] = {
    {"Sky terrace", "plateau", 430, -420}, {"Meteor crater", "crater", -90, 40},
    {"Stair falls", "falls", 760, 230}, {"Giant tree", "tree", -520, -520},
    {"Sea arch", "arch", -1180, 1010}, {"Red spire", "spire", -700, 450},
};

/* ---- 4. Windward crescent: an arc of ranges W-N, the forest belt in the lee -------------------------------- */
static const LFeat L4_F[] = {
    RANGE(-250, 1150, -900, 800, 270, 420, 540, 0.8f),
    RANGE(-900, 800, -1230, 150, 270, 540, 600, 0.8f),
    RANGE(-1230, 150, -1100, -550, 270, 600, 560, 0.8f),
    RANGE(-1100, -550, -600, -1050, 270, 560, 500, 0.8f),
    RANGE(-600, -1050, 100, -1330, 260, 500, 450, 0.8f),
    RANGE(100, -1330, 850, -1130, 250, 450, 330, 0.8f),
    RANGE(-650, 760, -760, 150, 160, 220, 240, 0.8f),     /* inner foothill arc */
    RANGE(-760, 150, -700, -420, 160, 240, 220, 0.8f),
    RANGE(-700, -420, -350, -700, 160, 220, 180, 0.8f),
    RANGE(250, 560, 450, 830, 130, 160, 150, 0.8f),        /* rampart before the canyon */
    NEST_RIM(340, 120, 150),
    PLATEAU(-1180, -330, 230, 100, 430),                  /* Karst plateau at the apex, gated */
    TERRACE(-480, -80, 400, 200, 22, 0.85f),              /* terraced bench, inner foothill flank */
    TERRACE(920, 330, 380, 220, 18, 0.7f),
    BADLANDS(300, 1050, 450, 120, 1.f),
    CHANNEL(0, 0, 330, 60, 120, 340, 40, 30, 0),          /* exit E: down the lee valley to the forest belt */
    CHANNEL(330, 60, 800, 160, 140, 380, 30, 14, 0),
    CHANNEL(800, 160, 1300, 250, 120, 320, 14, 0, 1),
    CHANNEL(0, 0, 100, 300, 70, 190, 42, 100, 0),         /* exit S: pass to the red canyon */
    CHANNEL(100, 300, 280, 640, 55, 140, 100, 70, 0),
    CHANNEL(280, 640, 360, 900, 40, 100, 70, 46, 0),      /* the red canyon through the rampart */
    CHANNEL(360, 900, 250, 1180, 40, 100, 46, 24, 0),
    CHANNEL(250, 1180, 160, 1460, 55, 150, 24, 0, 1),
    CHANNEL(0, 0, -330, -40, 70, 200, 42, 110, 0),        /* exit W: pass to the windward bench */
    CHANNEL(-330, -40, -600, -80, 100, 260, 110, 130, 0),
    CHANNEL(0, 0, -20, -330, 70, 200, 42, 105, 0),        /* exit N: col to the northern basin */
    CHANNEL(-20, -330, 120, -700, 100, 260, 105, 60, 0),
    ISLET(1050, 1140, 150, 160, 400),
};
static const LRegion L4_R[] = {
    {"Nest valley", "nest", 0, 1, 0, {{0, 0}}},
    {"Lee forest belt", "forest", 0, 5, 400, {{350, 60}, {700, 140}, {900, 450}, {800, 750}, {620, 950}}},
    {"Windward bench", "terraces", 0, 2, 300, {{-480, -80}, {-380, -520}}},
    {"Red canyon", "canyon", 0, 4, 220, {{280, 640}, {360, 900}, {250, 1180}, {300, 1050}}},
    {"Karst plateau", "plateau", 1, 1, 230, {{-1180, -330}}},
    {"Islet", "islet", 2, 1, 150, {{1050, 1140}}},
};
static const LRoute L4_T[] = {
    {"Exit E: lee valley", "exit", 4, {{0, 0}, {330, 60}, {800, 160}, {1300, 250}}},
    {"Exit S: red canyon", "exit", 5, {{0, 0}, {100, 300}, {280, 640}, {360, 900}, {160, 1460}}},
    {"Exit W: bench pass", "exit", 3, {{0, 0}, {-330, -40}, {-600, -80}}},
    {"Exit N: north col", "exit", 3, {{0, 0}, {-20, -330}, {120, -700}}},
};
static const LMark L4_M[] = {
    {"Gale Horn", "peak", -1180, -330}, {"Meteor crater", "crater", -90, 40},
    {"Red Arch", "spire", 330, 980}, {"Giant tree", "tree", 700, 200},
    {"Sea arch", "arch", 1050, 1140}, {"Karst plateau", "plateau", -1180, -330},
};

#define NLAYOUT 4
#define LAYOUT_ROW(ID, TITLE, STREAM, DROPS, F, R, T, M) \
    {ID, TITLE, 190.f, STREAM, DROPS, (int)(sizeof F / sizeof F[0]), (int)(sizeof R / sizeof R[0]), (int)(sizeof T / sizeof T[0]), \
     (int)(sizeof M / sizeof M[0]), F, R, T, M}
static const Layout LAYOUTS[NLAYOUT] = {
    LAYOUT_ROW("star-massif", "Star massif", 0, 0, L1_F, L1_R, L1_T, L1_M),
    LAYOUT_ROW("great-rift", "Great rift", 0, 0, L2_F, L2_R, L2_T, L2_M),
    LAYOUT_ROW("stepped-plateau", "Stepped plateau", 8, 10000, L3_F, L3_R, L3_T, L3_M),
    LAYOUT_ROW("windward-crescent", "Windward crescent", 0, 0, L4_F, L4_R, L4_T, L4_M),
};

static void sincos_deg(float deg, float *s, float *c)
{
    float x, z;
    while (deg > 180.f) deg -= 360.f;
    while (deg < -180.f) deg += 360.f;
    x = deg * 0.01745329252f; z = x * x;
    *s = x * (1.f + z * (-1.f/6.f + z * (1.f/120.f + z * (-1.f/5040.f + z * (1.f/362880.f + z * (-1.f/39916800.f + z * (1.f/6227020800.f)))))));
    *c = 1.f + z * (-1.f/2.f + z * (1.f/24.f + z * (-1.f/720.f + z * (1.f/40320.f + z * (-1.f/3628800.f + z * (1.f/479001600.f))))));
}

static float seg_dist(float px, float py, float ax, float ay, float bx, float by, float *t)
{
    float dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy, u = 0.f, qx, qy;
    if (l2 > 1.0e-6f) u = clampf(((px - ax) * dx + (py - ay) * dy) / l2, 0.f, 1.f);
    qx = ax + dx * u - px; qy = ay + dy * u - py;
    if (t) *t = u;
    return sqrtf(qx * qx + qy * qy);
}

/* Treads with short risers: h in steps of `step`, flat for 72% of each, then a smooth rise. */
static float stair(float h, float step)
{
    float u = h / step, fl = (float)ifloor(u), f = u - fl;
    return step * (fl + smoothstep(0.72f, 1.f, f));
}

/* The layout shape before erosion, metres above the sea. */
static float layout_height(const CpTerrainParams *p, const Layout *L, float x, float y)
{
    const float F = p->frequency, vr = L->nest_r, vf = p->valley_floor_m;
    const uint32_t S = p->seed;
    float r0 = sqrtf(x * x + y * y);
    float nx = (x + 8192.f) * F, ny = (y + 8192.f) * F;
    int woct = p->octaves > 3 ? 3 : p->octaves;
    float wfade = smoothstep(vr * 0.4f, 700.f, r0) * p->warp_m * 2.f;
    float X = x + fbm(nx * 0.55f, ny * 0.55f, woct, S ^ 0xA341316Cu) * wfade;
    float Y = y + fbm(nx * 0.55f + 4.2f, ny * 0.55f + 1.7f, woct, S ^ 0xC8013EA4u) * wfade;
    float r = sqrtf(X * X + Y * Y), ir = 1.f / maxf(r, 1.f), ux = X * ir, uy = Y * ir;
    float sx = nx + fbm(nx * 1.9f + 7.1f, ny * 1.9f + 3.3f, woct, S ^ 0x1F83D9ABu) * 0.22f;
    float sy = ny + fbm(nx * 1.9f + 1.4f, ny * 1.9f + 8.8f, woct, S ^ 0x9B05688Cu) * 0.22f;
    float rd = ridged(sx, sy, p->octaves, S ^ 0x510E527Fu);
    float rd2 = ridged(sx * 1.7f + 5.3f, sy * 1.7f + 9.1f, p->octaves, S ^ 0xBB67AE85u);
    float hills = fbm(sx * 2.3f, sy * 2.3f, p->octaves, S ^ 0x51F0EDE5u);
    float detail = 0.42f + 1.35f * rd;
    float moat = 0.f, peaks = 0.f, plat = 0.f, ground, h, cone = 0.f, mouth = 0.f, bay = 0.f, islet = -100.f;
    float a_coast = noise2(ux * 1.40f + 7.7f, uy * 1.40f + 13.3f, S ^ 0x5BE0CD19u);
    float a_coast2 = noise2(ux * 3.30f + 1.2f, uy * 3.30f + 19.9f, S ^ 0x6A09E667u);
    float coast_r, shore, edge;
    int i;

    /* crests: massifs, ranges and the nest rim take the max */
    for (i = 0; i < L->nf; i++) {
        const LFeat *f = &L->f[i];
        float q = 2.f, pk = 0.f;
        if (f->kind == LF_MASSIF) {
            float s, c, ex = X - f->x0, ey = Y - f->y0, a, b;
            sincos_deg(f->k, &s, &c);
            a = (ex * c + ey * s) / f->w2; b = (-ex * s + ey * c) / f->w;
            q = sqrtf(a * a + b * b);
            if (q < 1.6f && q > 1.0e-4f) q *= 1.20f - 0.34f * spur(a * 2.1f / q + 13.f * (float)i, b * 2.1f / q + 7.f, S ^ 0x62A9D9EDu);
            pk = f->h;
        } else if (f->kind == LF_RANGE) {
            float t, d = seg_dist(X, Y, f->x0, f->y0, f->x1, f->y1, &t), mod;
            float along = t * sqrtf((f->x1 - f->x0) * (f->x1 - f->x0) + (f->y1 - f->y0) * (f->y1 - f->y0));
            mod = clampf(0.80f + f->k * 0.50f * noise2(along / 380.f + 3.1f * (float)i, 0.5f + (float)i, S ^ 0x2D1FB7C3u), 0.35f, 1.15f);
            q = d / f->w;
            if (q < 1.6f && q > 1.0e-4f) q *= 1.18f - 0.32f * spur(X * (1.f / 260.f) + 11.f * (float)i, Y * (1.f / 260.f) + 5.f, S ^ 0x62A9D9EDu);
            pk = (f->h + (f->h2 - f->h) * t) * mod;
        } else if (f->kind == LF_RING) {
            float lobe = clampf(0.70f + 0.95f * noise2(ux * 2.4f + 5.f, uy * 2.4f + 9.f, S ^ 0x3C6EF372u), 0.22f, 1.15f);
            q = absf(r + 70.f * noise2(ux * 3.1f + 1.f, uy * 3.1f + 4.f, S ^ 0x7F4A7C15u) - f->w) / f->w2;
            pk = f->h * lobe;
        } else if (f->kind == LF_CONE) {
            float d = sqrtf((X - f->x0) * (X - f->x0) + (Y - f->y0) * (Y - f->y0)), u = 1.f - d / f->w;
            if (u > 0.f) cone = maxf(cone, f->h * u * (0.82f + 0.18f * u));
            continue;
        } else continue;
        if (q < 1.f) peaks = maxf(peaks, pk * (1.f - q) * (1.f - q) * (1.f + 0.5f * q));
    }

    /* ground: the nest bowl, an apron, and a fall to the coast */
    {
        float u = clampf(r0 / vr, 0.f, 1.f);
        ground = vf + 11.f * u * u + smoothstep(vr, 600.f, r) * 26.f;
        ground -= smoothstep(900.f, p->island_radius_m, r) * (ground - 4.f);
    }
    peaks *= 1.30f;
    for (i = 0; i < L->nf; i++) {   /* a plateau stands on its own: the ranges do not reach into it */
        const LFeat *f = &L->f[i];
        if (f->kind == LF_PLATEAU) {
            float d = sqrtf((x - f->x0) * (x - f->x0) + (y - f->y0) * (y - f->y0));
            plat = maxf(plat, 1.f - smoothstep(f->w, f->w + f->w2 * 2.f, d));
        }
    }
    peaks *= 1.f - plat;
    h = ground + cone + peaks * (0.40f + 0.60f * detail);
    h += clampf(peaks * (1.f / 220.f), 0.f, 1.f) * 45.f * rd2;
    h += hills * (3.f + 26.f * smoothstep(vr * 0.3f, vr * 1.1f, r0));

    /* plateaus */
    for (i = 0; i < L->nf; i++) {
        const LFeat *f = &L->f[i];
        if (f->kind == LF_PLATEAU) {
            float d = sqrtf((x - f->x0) * (x - f->x0) + (y - f->y0) * (y - f->y0));
            float w = f->w * (1.f + 0.14f * noise2(x * (1.f / 330.f) + 2.f * (float)i, y * (1.f / 330.f) + 8.f, S ^ 0x7F4A7C15u));
            float m = 1.f - smoothstep(w, w + f->w2, d);
            float top = f->h + 6.f * hills + 4.f * rd2;
            h = h * (1.f - m) + top * m;
        }
    }
    /* terraces: treads and risers, contours wobbled so they do not follow a ruler */
    for (i = 0; i < L->nf; i++) {
        const LFeat *f = &L->f[i];
        if (f->kind == LF_TERRACE) {
            float d = sqrtf((x - f->x0) * (x - f->x0) + (y - f->y0) * (y - f->y0));
            float zm = (1.f - smoothstep(f->w, f->w + f->w2, d)) * f->k;
            if (zm > 0.f && h > 4.f) {
                float hq = stair(h + f->h * 0.30f * noise2(x * (1.f / 420.f) + 3.f * (float)i, y * (1.f / 420.f) + 1.f, S ^ 0x4F1BBCDCu), f->h);
                h = h * (1.f - zm) + hq * zm;
            }
        }
    }
    /* badlands: mesas, buttes and gullies */
    for (i = 0; i < L->nf; i++) {
        const LFeat *f = &L->f[i];
        if (f->kind == LF_BADLANDS) {
            float d = sqrtf((x - f->x0) * (x - f->x0) + (y - f->y0) * (y - f->y0));
            float zm = 1.f - smoothstep(f->w * 0.65f, f->w, d);
            if (zm > 0.f) {
                float b = ridged(x * F * 2.6f * f->k + 9.f, y * F * 2.6f * f->k + 4.f, 4, S ^ 0x6A09E667u);
                float e = 0.5f * b + 0.5f * stair(b, 0.22f);
                h += zm * (f->h * e + 18.f);
            }
        }
    }
    /* channels: passes, river valleys and canyons cut into whatever stands there */
    for (i = 0; i < L->nf; i++) {
        const LFeat *f = &L->f[i];
        if (f->kind == LF_CHANNEL) {
            float t, cx = X + 55.f * noise2(X * 0.0065f, Y * 0.0065f, S ^ 0x1B873593u), cy = Y + 55.f * noise2(X * 0.0065f + 6.f, Y * 0.0065f + 2.f, S ^ 0xCC9E2D51u);
            float d = seg_dist(cx, cy, f->x0, f->y0, f->x1, f->y1, &t);
            float floor_h = f->h + (f->h2 - f->h) * t + 1.5f * hills;
            if (h > floor_h) {
                float s = smoothstep(f->w, f->w + f->w2, d);
                h = floor_h + (h - floor_h) * s;
            }
            if (f->k > 0.5f) {
                float md = sqrtf((f->x1 - X) * (f->x1 - X) + (f->y1 - Y) * (f->y1 - Y));
                mouth = maxf(mouth, 1.f - smoothstep(180.f, 480.f, md));
            }
        }
    }
    /* the nest: a bowl at the origin, unwarped, with the lake */
    {
        float u = clampf(r0 / vr, 0.f, 1.f), floor_h = vf + 11.f * u * u;
        float m = 1.f - smoothstep(vr * 0.55f, vr * 1.25f, r0);
        h = h * (1.f - m) + floor_h * m;
        h -= p->lake_depth_m * (1.f - smoothstep(p->lake_radius_m * 0.2f, p->lake_radius_m,
              sqrtf((x - p->lake_x_m) * (x - p->lake_x_m) + (y - p->lake_y_m) * (y - p->lake_y_m))));
    }

    /* islets and the bays cut for them */
    for (i = 0; i < L->nf; i++) {
        const LFeat *f = &L->f[i];
        if (f->kind == LF_ISLET) {
            float d = sqrtf((x - f->x0) * (x - f->x0) + (y - f->y0) * (y - f->y0));
            float w = f->w * (1.f + 0.18f * noise2(x * (1.f / 140.f), y * (1.f / 140.f) + 5.f, S ^ 0x7F4A7C15u));
            float m = 1.f - smoothstep(w * 0.55f, w, d);
            bay = maxf(bay, 1.f - smoothstep(f->w2 * 0.45f, f->w2 * 1.3f, d));
            moat = maxf(moat, 1.f - smoothstep(f->w + 130.f, f->w + 230.f, d));
            if (m > 0.f) islet = maxf(islet, -24.f + (f->h * (0.78f + 0.40f * rd2) + 24.f) * m);
        }
    }

    /* coast */
    coast_r = p->island_radius_m * (1.f + 0.16f * a_coast + 0.08f * a_coast2) - 380.f * bay;
    shore = smoothstep(coast_r - 260.f, coast_r + 40.f, r);
    edge = maxf(absf(x), absf(y)) / (p->size_m * 0.5f);
    shore = maxf(shore, smoothstep(0.80f, 0.97f, edge));
    if (p->sea_cliffs > 0.f) {
        float sector = smoothstep(-.02f, .20f, noise2(ux * 2.2f + 15.f, uy * 2.2f + 43.f, S ^ 0x315C94E7u));
        float cliffs = p->sea_cliffs * sector * (1.f - mouth) * smoothstep(.25f, .50f, shore) * smoothstep(22.f, 48.f, h);
        float face = smoothstep(.69f, .84f, shore);
        float shelf = 38.f + 14.f * a_coast2;
        float rocky = maxf(h, shelf) * (1.f - face) - 24.f * face;
        h = (h * (1.f - shore) - 24.f * shore) * (1.f - cliffs) + rocky * cliffs;
    } else h = h * (1.f - shore) + (-24.f) * shore;
    h = h * (1.f - moat) + (-32.f) * moat;   /* a channel of open water round each islet */
    if (islet > h) h = islet;
    return h;
}

/* JSON for the design maps: one object per layout, ascii, no allocation. Returns bytes written (excluding NUL). */
size_t cp_terrain_layout_json(int layout, char *buf, size_t cap)
{
    size_t n = 0;
    const Layout *L;
    if (!buf || cap < 2) return 0;
    buf[0] = 0;
    if (layout < 1 || layout > NLAYOUT) return 0;
    L = &LAYOUTS[layout - 1];
#define EMIT(...) do { if (n < cap) { int w_ = snprintf(buf + n, cap - n, __VA_ARGS__); if (w_ > 0) n += (size_t)w_; } } while (0)
#define PTS(arr, cnt) do { for (int k_ = 0; k_ < (cnt); k_++) EMIT("%s[%.0f,%.0f]", k_ ? "," : "", (double)(arr)[k_][0], (double)(arr)[k_][1]); } while (0)
    EMIT("{\"id\":\"%s\",\"title\":\"%s\",\"nest_r\":%.0f,\"params\":{\"layout\":%d,\"valley_radius_m\":%.0f,\"stream_iters\":%d,\"droplets\":%d},\"regions\":[", L->id, L->title, (double)L->nest_r,
         layout, (double)L->nest_r, L->stream ? L->stream : 48, L->droplets ? L->droplets : 80000);
    for (int i = 0; i < L->nreg; i++) {
        const LRegion *r = &L->reg[i];
        EMIT("%s{\"name\":\"%s\",\"kind\":\"%s\",\"gate\":%d,\"w\":%.0f,\"pts\":[", i ? "," : "", r->name, r->kind, r->gate, (double)r->w);
        PTS(r->p, r->n); EMIT("]}");
    }
    EMIT("],\"routes\":[");
    for (int i = 0; i < L->nroute; i++) {
        const LRoute *r = &L->route[i];
        EMIT("%s{\"name\":\"%s\",\"kind\":\"%s\",\"pts\":[", i ? "," : "", r->name, r->kind);
        PTS(r->p, r->n); EMIT("]}");
    }
    EMIT("],\"marks\":[");
    for (int i = 0; i < L->nmark; i++) {
        const LMark *m = &L->mark[i];
        EMIT("%s{\"name\":\"%s\",\"kind\":\"%s\",\"x\":%.0f,\"y\":%.0f}", i ? "," : "", m->name, m->kind, (double)m->x, (double)m->y);
    }
    EMIT("]}");
#undef EMIT
#undef PTS
    return n < cap ? n : cap - 1;
}

/* The recommended parameters of a layout (nest valley radius, erosion strength) on top of the defaults. */
void cp_terrain_layout_apply(int layout, CpTerrainParams *p)
{
    const Layout *L;
    if (!p || layout < 1 || layout > NLAYOUT) return;
    L = &LAYOUTS[layout - 1];
    p->layout = (float)layout;
    p->valley_radius_m = L->nest_r;
    if (L->stream) p->stream_iters = L->stream;
    if (L->droplets) p->droplets = L->droplets;
}
