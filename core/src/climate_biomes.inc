/* cpore - biome lookup for core/src/climate.c (plan section 4.2 step 7).
 *
 * A Whittaker (1975) biome diagram lookup on (mean annual temperature T in C,
 * annual precipitation P in mm), first matching row wins.  Whittaker's diagram
 * (R. H. Whittaker, Communities and Ecosystems, 2nd ed. 1975, Fig. 5-5) plots
 * biome type over T and P; its boundaries are read off it by eye here and are
 * STARTING VALUES that the M2 region gates on Star massif check, not
 * measurements.  Our climate is cool (F15: 14 C at sea level, 6.2 K/km), so
 * the cold rows sit at higher T than Whittaker's tundra (his tundra is below
 * about -5 C): they are the canon snowline and treeline mapped onto the
 * scale_z 2.5 heights (plan Q3).  The thresholds T_TREELINE and T_TUNDRA are
 * CpClimateParams-independent here; snow is decided in climate.c from
 * CpClimateParams.snow_C.
 *
 * Row: t_lo <= T < t_hi and p_lo <= P < p_hi.
 */
typedef struct { float t_lo, t_hi, p_lo, p_hi; uint8_t biome; } CpBiomeRow;

static const CpBiomeRow CP_BIOME_TABLE[] = {
    /* Whittaker: tundra is the coldest band at any P (here: below the alpine zone, above the snowline) */
    { -100.f,   4.5f,    0.f, 1e9f, CP_BIOME_TUNDRA },
    /* treeline: Koerner's 6-7 C growing-season isotherm; here T < 7 C mean annual (about 450 m game height) */
    {    4.5f,  7.0f,    0.f, 1e9f, CP_BIOME_ALPINE },
    /* Whittaker: desert, P below about 250 mm at any temperature that is not freezing */
    {    7.0f, 100.f,    0.f,  250.f, CP_BIOME_DESERT },
    /* Whittaker: woodland/shrubland/dry grassland band, about 250-450 mm */
    {    7.0f, 100.f,  250.f,  450.f, CP_BIOME_SCRUB },
    /* Whittaker: temperate grassland, about 450-900 mm */
    {    7.0f, 100.f,  450.f,  900.f, CP_BIOME_MEADOW },
    /* Whittaker: temperate seasonal forest, about 900-1700 mm (dry forest on the island) */
    {    7.0f, 100.f,  900.f, 1700.f, CP_BIOME_DRY_FOREST },
    /* Whittaker: temperate rain forest above about 1700 mm; here the cloud forest (A99 (5)) */
    {    7.0f, 100.f, 1700.f, 1e9f, CP_BIOME_JUNGLE },
};
#define CP_BIOME_ROWS ((int)(sizeof CP_BIOME_TABLE / sizeof CP_BIOME_TABLE[0]))
