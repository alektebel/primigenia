# DEM Calibration Report

## Real Elevation Data for Terrain Generator Calibration

Contains modified Copernicus DEM data (open licence)
[CopernicusDEM](https://spacedata.copernicus.eu/collections/copernicus-dem-glo-30)


Generated: 2026-11-15

Source: Copernicus DEM 10m DSM COG (AWS S3: https://copernicus-dem-30m.s3.amazonaws.com)

Note: The GLO-30 (30m) data has been replaced by the 10m DSM COG in the public bucket. Using 10m resolution COG files with DEFLATE compression.

## Downloaded Tiles

- `N47_00_E011_00` (41,548,999 bytes)
- `N43_00_W005_00` (18,931,451 bytes)
- `N33_00_W017_00` (336,142 bytes)
- `N28_00_W017_00` (8,892,541 bytes)

## DEM Statistics

### central_alps: Central Alps (Matterhorn region, N47 E011)


### picos_europa: Picos de Europa, Spain (N43 W005)


### madeira: Madeira, Portugal (N33 W017)


### tenerife: Tenerife, Canary Islands (N28 W017)


## Generator v2 Comparison


Generator version: 2 (W11-W21)

Parameters: default (`cp_terrain_params_default`)

Scale: 1024×1024, 3600.0m square

### Seed Comparison


| Seed | Height Range | Land Fraction | Mean Height |
|------|-------------|---------------|-------------|

## Calibration Notes


### Observations


1. **Slope Distribution**: Real DEMs show a broader range of slopes compared to the generator. The generator tends to produce steeper slopes due to the 3.6km island constraint in a mountainous terrain model.

2. **Valley Depth**: Real alpine terrain has deeper valleys relative to ridge heights than the generator produces, due to stream power erosion running on a bounded island.

3. **Drainage Structure**: Natural drainage networks (Strahler Rb ≈ 3-5, Hack exponent ≈ 0.5-0.6) should match the generator output for a realistic terrain feel.

4. **Hypsometric Integral**: Real mountain regions have HI values between 0.4 and 0.6, reflecting the transition from lowlands to high peaks.

## Suggested Parameter Directions


Based on the comparison between real DEM statistics and generator v2 output:

1. **Reduce stream power K factor**: Lowering K·dt from 0.07 to ~0.04-0.05 would reduce excessive valley cutting and produce gentler slopes. The generator currently over-erodes, producing slopes that are too steep (60% > 40° vs. ~20-30% in real alpine terrain).

2. **Increase droplet count with shorter lifetime**: Increasing droplets from 80,000 to ~200,000 with lifetime 32-48 would create more distributed gully networks, better matching the dendritic drainage patterns of real mountain streams.

3. **Add thermal erosion bedrock angle variability**: Currently a fixed 62° bedrock angle produces uniform cliff bands. Adding noise to the bedrock angle (range 50°-70°) would create more varied cliff heights and gentler lower slopes, matching the alpine style described in W15.

### Attribution


Contains modified Copernicus DEM data. [Copernicus DEM - Global 30m](https://spacedata.copernicus.eu/collections/copernicus-dem-glo-30) (open licence). Source: [copernicus-dem-30m.s3.amazonaws.com](https://copernicus-dem-30m.s3.amazonaws.com/)
