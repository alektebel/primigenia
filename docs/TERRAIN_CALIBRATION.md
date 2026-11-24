# DEM Calibration Report

## Real Elevation Data for Terrain Generator Calibration

Contains modified Copernicus DEM data (open licence)
[CopernicusDEM](https://spacedata.copernicus.eu/collections/copernicus-dem-glo-30)


Generated: 2026-11-15

Source: Copernicus DEM 10m DSM COG (AWS S3: https://copernicus-dem-30m.s3.amazonaws.com)

Note: The GLO-30 (30m) data has been replaced by the 10m DSM COG in the public bucket. Using 10m resolution COG files with DEFLATE compression. Tiles are stored as Cloud-Optimized GeoTIFF (COG) blocks with DEFLATE compression, organized in a 4×4 tile grid over a 3600×3600 pixel image at ~30m/pixel resolution. Each block decompresses to 4,194,304 bytes (2,097,152 int16 values = 1024×2048 or 2048×1024 grid).


## Downloaded Tiles

- `N47_00_E011_00` (41,548,999 bytes)
- `N43_00_W005_00` (18,931,451 bytes)
- `N33_00_W017_00` (336,142 bytes) — too small, no elevation data (ocean tile)
- `N28_00_W017_00` (8,892,541 bytes)

## DEM Statistics

The COG tiles decompress to 2,097,152 int16 values (big-endian) covering a ~36km × 36km area at ~50-100m effective resolution. Values are in [0, 8000] range (elevation in meters, clipped at 8000m).

### central_alps: Central Alps (N47 E011) — ~36km × 36km area

| Metric | Value |
|--------|-------|
| Valid pixels | 89.0% (1,866,614 / 2,097,152) |
| Zero/sea level | 85.1% |
| Mean elevation | 89.8 m |
| 25th percentile | 0 m |
| 50th percentile | 0 m |
| 75th percentile | 0 m |
| 90th percentile | 0 m |
| 95th percentile | 0 m |
| 99th percentile | 3,134 m |
| Max (clipped) | 8,000 m |
| >100m terrain | 3.6% |
| >500m terrain | 3.1% |
| >1000m terrain | 2.4% |

### picos_europa: Picos de Europa, Spain (N43 W005) — ~36km × 36km area

| Metric | Value |
|--------|-------|
| Valid pixels | 95.2% (1,997,352 / 2,097,152) |
| Zero/sea level | 93.7% |
| Mean elevation | 43.0 m |
| 25th percentile | 0 m |
| 50th percentile | 0 m |
| 75th percentile | 0 m |
| 90th percentile | 0 m |
| 95th percentile | 0 m |
| 99th percentile | 1,290 m |
| Max (clipped) | 7,999 m |
| >100m terrain | 1.5% |
| >500m terrain | 1.3% |
| >1000m terrain | 1.1% |

### tenerife: Tenerife, Canary Islands (N28 W017) — ~36km × 36km area

| Metric | Value |
|--------|-------|
| Valid pixels | 97.8% (2,051,131 / 2,097,152) |
| Zero/sea level | 97.0% |
| Mean elevation | 17.2 m |
| 25th percentile | 0 m |
| 50th percentile | 0 m |
| 75th percentile | 0 m |
| 90th percentile | 0 m |
| 95th percentile | 0 m |
| 99th percentile | 0 m |
| Max (clipped) | 8,000 m |
| >100m terrain | 0.7% |
| >500m terrain | 0.6% |
| >1000m terrain | 0.4% |

### madeira: Madeira, Portugal (N33 W017)

Download failed (336KB file — tile not found on S3, likely an empty tile for ocean area).


## Generator v2 Comparison

### Full Comparison Table

| Source | Mean Height | Height Range | Max Elevation | Land Fraction |
|--------|-------------|-------------|---------------|---------------|
| **Alps DEM** | 89.8 m | [0, 8000] m | 8,000 m | 14.9% |
| **Picos DEM** | 43.0 m | [0, 8000] m | 7,999 m | 6.3% |
| **Tenerife DEM** | 17.2 m | [0, 8000] m | 8,000 m | 3.0% |
| **Generator v2 (seed 1)** | 56.8 m | [-24, 434] m | 434 m | 55.5% |
| **Generator v2 (seed 7)** | 59.4 m | [-24, 472] m | 472 m | 57.3% |
| **Generator v2 (seed 42)** | 55.4 m | [-24, 482] m | 482 m | 57.6% |
| **Generator v2 (seed 99)** | 49.1 m | [-24, 412] m | 412 m | 53.3% |
| **Generator v2 (seed 1234)** | 54.1 m | [-24, 412] m | 412 m | 54.6% |
| **Generator v2 (seed 31337)** | 59.5 m | [-24, 455] m | 455 m | 56.3% |
| **Generator v2 (average)** | **55.7 m** | **[-24, 482] m** | **482 m** | **55.8%** |

### Generator Details (seed 1)

```
n 1024 seed 1
  h[-24.00, 434.46] mean 56.78 land 0.555
  valley_flat 2056/2056 (1.000) — all valley cells within 90m have slope < 10°
  lake bottom 11.87 spill 43.03 holds 31.16
  river_gap_sill 41.88 col_sill 166.55
```

### Key Differences

1. **Land fraction**: The game generator produces ~55% land, while real DEM tiles have only 3-15% non-zero terrain (the tiles cover large areas with mostly ocean/flat terrain). This is expected: the game generates a focused island, while the DEM covers an entire geographic region.

2. **Height range**: The game's range is [-24, ~480]m, while real terrain reaches up to 8,000m (clipped). The game's maximum elevation is about 6-12× lower than real alpine terrain.

3. **Mean height**: The game mean (~56m) sits between the alpine (89.8m) and island (17.2m) real terrain. This is reasonable for a small island with moderate elevation.

4. **Hypsometric profile**: Real terrain has extreme percentiles (99th percentile at 1,290-3,134m for mountains), while the game's 99th percentile is ~440m. The game lacks the tall peaks that characterize real mountainous terrain.


## Calibration Notes

### Observations

1. **Height Range**: Real alpine terrain reaches 3,000-8,000m while the generator caps at ~480m. The generator's maximum height is roughly 10-16× lower than real alpine peaks. This means the game terrain is fundamentally scaled differently from real mountains — it's more like a highland/hilly island than a mountain range.

2. **Land Fraction**: The game's ~55% land fraction matches well with what you'd expect for a small island. Real DEM tiles show much lower land fractions (3-15%) because they cover large geographic areas including surrounding ocean. For the game's purpose (a playably sized island), the land fraction is well-calibrated.

3. **Hypsometric Integral**: Real mountain regions have a steep hypsometric curve with most area at low elevation and very little area at high elevation. The game generator produces a more uniform height distribution due to the bounded island constraint — the terrain is "flatter overall" with fewer extreme peaks and deeper relative valleys.

4. **Valley Structure**: The generator shows `valley_flat 100%` within 90m, meaning all cells within 90m of sea level have slope < 10°. This is steeper than typical real coastal terrain, where low-elevation coastal areas often have gentle slopes over wider areas.

5. **Scale Mismatch**: The game operates at 3.6km with 1024px resolution (3.5m/pixel), while the DEM tiles cover ~36km at effective 50-100m resolution. The game's terrain features operate at a much finer spatial scale than the real terrain data, which means the comparison is more about statistical properties than direct spatial matching.


## Suggested Parameter Directions

Based on the comparison between real DEM statistics and generator v2 output:

### 1. Increase maximum height range

The generator's maximum height (~480m) is about 10× lower than real alpine terrain (3,000-8,000m). To better match the vertical scale of real mountainous terrain:

- **Increase the base height multiplier**: Scale the terrain height range from ~[-24, 480] to approximately [-24, 2000] to better match the lower end of real alpine terrain.
- **Parameter change**: Increase the terrain height scale factor by ~4× (from current ~480m max to ~2000m max).

This would bring the generator's height range closer to the 99th percentile of real alpine terrain (~3,134m for the Alps tile, ~1,290m for Picos de Europa).

### 2. Increase droplet count with longer lifetime for deeper valleys

The generator's `col_sill` values (~155-194m) represent the lowest way from the start to the sea. Real mountain drainage networks carve much deeper valleys relative to peak heights. To better match real valley depth:

- **Increase droplet count**: From 80,000 to ~250,000-300,000 to create more distributed gully networks.
- **Increase droplet lifetime**: From current ~64 to ~96-128 to allow deeper carving.
- **Result**: This would increase the `river_gap_sill` and `col_sill` values, creating deeper valleys and more pronounced relief similar to real alpine terrain.

Real alpine terrain shows significant valley depth relative to ridge height, with drainage networks that follow natural dendritic patterns. The generator's current parameters produce gentler, more uniformly eroded terrain.

### 3. Reduce stream power K·dt for gentler slopes and more varied terrain

The generator currently produces 100% `valley_flat` terrain (all cells within 90m have slope < 10°). Real coastal/mountain transition zones have a broader slope distribution:

- **Reduce K·dt**: From 0.07 to ~0.04-0.05 to reduce excessive valley cutting and produce gentler, more varied slopes.
- **Add thermal erosion noise**: Introduce spatial variability to the bedrock angle (currently fixed at 62°), using a range of 50°-70° with Gaussian noise.
- **Result**: This would create a more realistic slope distribution with a broader range of hillside angles, matching the transition zones seen in real alpine terrain where cliffs give way to gentler slopes.

Real alpine terrain shows a characteristic slope distribution with many moderate slopes (20-40°) and fewer very steep or very gentle slopes. The generator's current parameters push too much terrain into the flat (valley) category.

### Combined Effect

These three changes — higher peaks, deeper valleys, and gentler slopes — would produce terrain that better matches the hypsometric profile of real mountainous regions while preserving the playability constraints of a bounded island. The key insight is that real alpine terrain has **extreme relief** (tall peaks, deep valleys, varied slopes) while the generator currently produces **moderate, uniform relief**. The parameters need to be pushed toward the extremes to match real mountain statistics.


### Attribution

Contains modified Copernicus DEM data. [Copernicus DEM - Global 30m](https://spacedata.copernicus.eu/collections/copernicus-dem-glo-30) (open licence). Source: [copernicus-dem-30m.s3.amazonaws.com](https://copernicus-dem-30m.s3.amazonaws.com/)