# H0 spike: HDR SubViewport LUTs for the Hillaire sky (Compatibility measured, Forward+ not)

Step H0 of `docs/plans/island-realism.md` §7.5. Script: `godot/game/tests/atmo_spike.gd` (throwaway). Raw numbers: `docs/evidence/sky/h0-spike-compat.json`.
Run: `LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 500 xvfb-run -a godot --rendering-driver opengl3 --resolution 640x360 --path godot --script res://game/tests/atmo_spike.gd -- out=<json>`.
Machine: Godot 4.7.2, Compatibility (GL 4.6, Mesa llvmpipe, software). The same script runs on Forward+ with `--rendering-method forward_plus`.

## Verdict
**Compatibility can do all of it with no fallback.** An HDR `SubViewport` is a real half-float target, a sky shader and a spatial shader sample it correctly (also through `global uniform sampler2D`), and the aerial-perspective volume works as a 1024×32 2D atlas with alpha. RGBM and the CPU sky-view are not needed.

**Forward+ was not measured.** The build environment has no software Vulkan ICD (only the owner's NVIDIA and Radeon ICDs, which the rules forbid using). Run the same script on a machine with a GPU to fill that column.

## Method
A generator writes known values: R = 10^(−5 + 7x/(w−1)) (1e-5 to 100), G = ramp 0..1, B = ramp 0..8, A = 1. A consumer (canvas, sky or spatial shader) samples the texture at texel centres, compares it with the analytic value **inside the shader** and writes the relative error, log-encoded in 0.25..1, into an HDR viewport that is read back.
Why in-shader: a 3D scene rendered into an HDR `SubViewport` comes back through a non-identity curve in Compatibility (constant 0.01 reads 0, 0.1 reads 0.089, 2 reads 2.04, 100 reads 205; only 0.25..1 is identity within 1e-3). Raw readback of sky/spatial output is therefore not a measurement of the sampler. This matters only for tests that read back a 3D HDR viewport. The game draws to the window, not to a viewport.

## Findings (Compatibility)
| Question | Result |
|---|---|
| Does `SubViewport.use_hdr_2d = true` give a float target? | Yes. Behaves as RGBA16F: 1000 and 60000 read back exactly, 70000 clamps to 65504, 1e-6 survives as a half subnormal (9.54e-7), 1e-8 flushes to 0. `get_image()` returns `FORMAT_RGBAF`. With `use_hdr_2d = false` it is RGBA8: clamps at 1.0, the test pattern reads 100 % wrong. |
| Precision of the HDR target | Normal range (≥ 6.1e-5): max relative error 9.0e-4 (half mantissa). 192×108 and 32×32 sizes: ≤ 9.2e-4. Only the subnormal band (1e-5 to 6e-5) reaches 4.6e-3. |
| Alpha in an HDR viewport (aerial perspective mean transmittance) | Preserved with `transparent_bg = true` and `render_mode blend_disabled` in the generator. Max error over the 32 slices: 4.7e-4. |
| Sky shader samples the viewport texture | Yes. Same error as the canvas consumer. Bilinear filtering of float data is exact (half-texel shift test: ≤ 4.3e-3, subnormal band only). |
| Spatial shader samples it | Yes, identical numbers. |
| `global uniform sampler2D` (the plan's `atmo_*` globals) | Works in canvas, sky and spatial, for a viewport texture and for an `ImageTexture`, and survives `global_shader_parameter_set` swaps. |
| The other LUT sizes (32×32, 192×108) as GPU HDR viewports | Sampled from sky and spatial with ≤ 9.2e-4 error. |
| Aerial perspective 32×32×32 as a 1024×32 atlas, manual trilinear between 2 slices | Works in sky and spatial at w = 0, 0.37, 1: rgb error 0, alpha error 4.1e-4. |
| Native 3D texture | `ImageTexture3D` (RGBAH, 32³) uploaded from the CPU is sampled correctly (error 0) in sky and spatial. It cannot be a render target in Compatibility, so the atlas stays. |
| LDR source (`use_hdr_2d = false`) | 8 bit, clamps at 1: unusable for LUTs; confirmed as the control. |

## Gotchas for H1/H2 (found, not in the plan)
1. **CPU-built half textures flush subnormals.** `ImageTexture` `FORMAT_RGBAH`/`RGBH` built with `set_pixel` reads 0 for every value under 6.1e-5 (1856 of 16384 test texels), whereas `FORMAT_RGBAF` is exact and filters correctly. GPU-rendered half targets keep the subnormals. **Upload the transmittance and multi-scattering LUTs as `FORMAT_RGBAF`** (256×64×16 B = 262 kB, 16 kB for the 32×32): costs nothing and avoids the bug. Blue transmittance at a low sun is the first thing that would break. Linear filtering of RGBAF worked here (desktop GL); on WebGL2 it needs `OES_texture_float_linear`, so check that if the web build is ever a target.
2. **`SCREEN_UV` in a `shader_type sky` is not a 0..1 screen coordinate in Compatibility** (read 0.5 to 19.9 across a 16×8 viewport). Use `EYEDIR` (the sky-view lookup does anyway) or `FRAGCOORD.xy / viewport_size`.
3. Half range ceiling: 65504, and an overflow clamps rather than becoming inf. Radiance after `sky_ev` is far below it; keep exposure applied before writing the sky-view if the sun-disc term is ever baked in.
4. RGBM (range 8) fallback, measured but not needed: sky-like colours round trip within 0.94 % for L from 0.01 to 8, 8.4 % below L = 0.01 (dim channels). Real LUT data with channels a million apart (my test pattern) is destroyed by RGBM, so it is a last resort only.
5. Running the script under `--script` prints devtools/autoload errors (the extension is not built in this worktree). They are harmless noise.

## Cost (relative; software GL, so CPU time, not GPU time)
Median of 5 batches of 20 frames, delta over an empty frame; two runs agreed within 0.3 ms. The paper's GTX 1080 figure is in the last column. Passes are reduced single-scattering versions with the paper's loop counts.

| Pass | Size, steps | llvmpipe ms/frame | Paper PC |
|---|---|---|---|
| Transmittance (once) | 256×64, 40 | 0.6 | 0.01 ms |
| Multi-scattering (once) | 32×32, 64 dirs × 20 | 11.5 to 12.4 | 0.07 ms |
| Sky-view (per frame) | 192×108, 30 | 1.9 to 2.0 | 0.05 ms (200×100) |
| Sky-view low tier | 96×50, 8 | 0.25 to 0.45 | iPhone 0.27 ms |
| Aerial perspective atlas (per frame) | 1024×32, 30 | 1.9 | 0.04 ms (32³) |
| Sky shader at 640×360, constant gradient | | 1.0 | |
| Same, sampling the sky-view LUT | | 1.1 to 1.4 (+10 to 30 %) | |
| Spatial quad 640×360, plain | | 1.0 to 1.6 | |
| Same, 2 atlas fetches per fragment | | 1.2 to 1.7 (+5 to 15 %) | |

Reading: the two per-frame LUT passes (sky-view + AP) cost about 4 ms here, about four plain 640×360 fills. They do not scale with screen size. Sampling the LUTs from the sky and from lit meshes adds 5 to 30 % to those shaders. Multi-scattering at 12 ms is a **load-time-only** cost on the GPU and does not belong in a frame; that supports the plan's choice to build it on the CPU once. The ratios say nothing precise about a real GPU (fill vs ALU balance differs); they show nothing is pathologically slow. Real GPU numbers are for H2's frame-time ratio gate (≤ 1.05).

## Recommendation for H1 and H2
1. **Keep the plan as written.** No format fallback: sky-view and AP as `use_hdr_2d` SubViewports, atlas for AP (1024×32 high, 32×32×16 low as 512×32).
2. **H1:** upload transmittance and multi-scattering as `FORMAT_RGBAF`, not RGBH (gotcha 1). Add that to the `atmo_test.gd` acceptance: a LUT texel below 6e-5 must survive upload.
3. **H2:** index the sky-view from `EYEDIR`, never `SCREEN_UV` (gotcha 2). The viewports are `UPDATE_ALWAYS`, `transparent_bg = true` for the AP atlas (its alpha holds mean transmittance) with `render_mode blend_disabled` in the generator.
4. Do not add a shader-side test that reads back sky/spatial output through an HDR viewport and compares numbers: use the in-shader error encoding of this spike, or compare in 0.25..1.
5. **Before H2 lands on a GPU:** run this script once with `--rendering-method forward_plus` on a machine with Vulkan to confirm the Forward+ column (expected identical: `use_hdr_2d` is the same API) and take real frame times.

## Blockers
None for Compatibility. Open: Forward+ unmeasured (no software Vulkan in the build environment); real-GPU cost unmeasured.
