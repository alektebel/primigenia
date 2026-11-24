# Climate reference (plan `docs/plans/island-realism.md` section 4, steps M0 and M1)

`lt_ref.py` is the plain-Python reference (no numpy; numpy is not installed) of the Smith & Barstad (2004) linear theory of orographic precipitation. The C kernel `core/src/climate.c` is tested against it.

```
python3 tools/climate/lt_ref.py check      # self checks (8, all PASS)
python3 tools/climate/lt_ref.py figure     # docs/evidence/island/climate/ref/lt_ref.jpg (needs ImageMagick for text and JPG)
python3 tools/climate/lt_ref.py fixtures   # tests/fixtures/climate/lt_{gauss,ridge,bumpy,island}.bin (n = 64, with P and qc)
```

Fixtures are committed; regenerate them only when the reference changes on purpose (the C test then tells you).

## Sources read

| Source | Reached | What it gave |
|---|---|---|
| R. B. Smith and I. Barstad, "A Linear Theory of Orographic Precipitation", AMS 2003 extended abstract 6.4 (https://ams.confex.com/ams/pdfpapers/62756.pdf; the host redirects to studio.m-anage.com) | read in full (6 pages) | equations 1a, 1b, 2, 3, 4, 5; the triangle-ridge parameters and figure; the truncation remark |
| I. Barstad and R. B. Smith, "Evaluation of an orographic precipitation model", J. Hydrometeorology 6 (2005) 85-99 (the plan's URL, through the web-archive id_ form) | read pages 1-4 and the sections that matter | the model summary with the symbol table (Table 2); eq. (3): `P(x,y) = ∫∫ P̂ e^{i(kx+ly)} dk dl + P∞`; the Gaussian-mountain sensitivity study (Fig. 1) |
| Smith and Barstad, J. Atmos. Sci. 61 (2004) 1377-1391 | **not reachable** (the AMS site returns 403; no open copy was found) | nothing directly |
| PISM `LinearTheoryOrographicPrecipitation` (github.com/pism, Python, "implements the LT model of Smith and Barstad"), `linear_orog_precip.py`; and fastscape-lem `orographic-precipitation` | read the code | the m-branch as implemented, and a closed-form triangle-ridge solution used as a test |

## Quotes

Abstract, equations (1a), (1b): `U·∇q_c = S_ref(x,y) − q_c/τ_c`, `U·∇q_h = q_c/τ_c − q_h/τ_h`. "The source term (S) in (1a) can be the classical upslope form `S = C_w U·∇h(x,y)` (Smith, 1979)." "The last term in (1b) is the precipitation rate at the ground (P)."

Eq. (2): `P̂(k,l) = C_w i σ ĥ(k,l) / ( [1 − i m H_w][1 + i σ τ_c][1 + i σ τ_h] )`.
Eq. (3): `m = { [(N_m² − σ²)/σ²] (k² + l²) }^½`. Eq. (4): `C_w = ρ_v0 (Γ_m/γ)`.
"The negative sign in the dynamics factor gives an upwind shift to the precipitation pattern while the positive signs in the cloud factors cause a downstream shift."
"When m = τ_c = τ_f = 0, (2) reduces to the standard upslope model with no airflow dynamics and no condensed water advection (Smith, 1979)."
"The reduction in precipitation efficiency due to downslope evaporation is not contained explicitly in (2), but is present when the predicted precipitation field P(x,y) is truncated according to P_Trun(x,y) = Maximum(P,0)."

Triangle ridge (abstract Fig. 1): T₀ = 280 K, γ = −5.8 °C/km, U = 15 m/s so Γ_m = −6.5 °C/km, N_m = 0.005 s⁻¹, ρ_Sref = 7.4 g/m³, H_w = 2500 m, h_m = 500 m, τ_c = τ_f = 1000 s, a = 15 km. "The raw upslope model predicts a constant value of condensation, P = 15 mm/hr, over the windward slope, and an equal negative value over the lee slope. The effect of airflow dynamics is to reduce the total condensation and shift the maximum upwind, close to the 'slope-break' of the triangle ridge. The source term becomes negative slightly upstream of the hill crest. The effect of cloud delay reduces the precipitation further, and shifts the precipitation peak downstream. The precipitation maximum (3 mm/hr) is located close to the hill top."

Barstad and Smith 2005 section 2: "P(x,y) = ∫∫ P̂(k,l) e^{i(kx+ly)} dk dl + P∞" (eq. 3); Table 2: background precipitation rate P∞ 0-5 mm h⁻¹; "Negative precipitation generated in strong downdrafts is unphysical and is truncated away." "The model reduces to the raw upslope model when H_w = τ_c = τ_f = 0 and C_w = ρ_v0."

## The two items the plan marked "verify in JAS section 2"

**1. P∞ and the truncation.** Verified in the sources I could reach, in this order: the 2005 paper puts `P∞` inside `P` (eq. 3, "+ P∞"), and says negative precipitation "is truncated away". The abstract says the truncated field is `Max(P, 0)`. So `P = max( IFFT(P̂) + P∞, 0 )`, the plan's form. The PISM code does the same (`P += P0; P[P<0] = 0`). **Not seen in the JAS text itself.** The kernel adds `P∞` before truncation (`CpLtParams.P0`, mm/h).

**2. The m-branch.** **Not verified in the paper text**: the abstract gives only eq. (3), and the 2005 paper does not repeat m. Verified in code: PISM computes `m = sqrt(m²)` as a complex number and multiplies by `sign(σ)` where `m² >= 0` and `σ != 0`, so the propagating case is `m = sgn(σ)·√(m²)` and the evanescent case (`m² < 0`) keeps the principal root `m = +i√(−m²)`. Then `1 − i m H_w = 1 + H_w √(−m²)`: real, larger than 1, a pure amplitude reduction with no phase shift. This is what the plan wrote, and what `lt_ref.py` and `climate.c` implement. The fastscape-lem implementation differs (it clamps `N_m² − σ²` at 0, which drops the evanescent damping); I did not follow it. PISM's version is checked below against a closed-form solution (with `H_w = 0`, which does not exercise the branch). **The branch itself has no independent check here beyond matching PISM and the abstract's qualitative statements** (dynamics lower the total and shift the peak upwind, source negative upstream of the crest).

Also, the JAS paper includes the Coriolis frequency in `m²` (PISM: `σ² − f²` in the denominator); the abstract's eq. (3) has no `f`. We use no Coriolis term, a deliberate omission: f is about 7e-5 s⁻¹ at 27° N, small against the σ of about 1e-3 s⁻¹ that matters at the island's climate scale.

## What the reference reproduces (all in `check`)

- Cw from eq. 4 with the abstract's numbers (7.4 g/m³ × 6.5/5.8) gives 8.29e-3 kg/m³ and a raw upslope of **14.93 mm/h** on the ridge: the abstract's "15 mm/hr".
- `H_w = τ = 0` reproduces the upslope model (windward 14.88-14.97 mm/h, lee the equal negative value).
- Closed form for one delay (H_w = 0, τ_c = 0, τ_f = τ): the numeric LT matches `C(1−e^{−(x+d)/Uτ})` on the windward slope and `C((2−e^{−d/Uτ})e^{−x/Uτ} − 1)` on the lee, to 0.001 mm/h. I derived it from (1a,1b); it is the same closed form as PISM's `triangle_ridge_exact`.
- The abstract's full case: the maximum is **2.92 mm/h at x = +0.4 km** (abstract: "3 mm/hr ... close to the hill top"); with dynamics only the peak is at x = −12.4 km, so the delays move it downstream by 12.8 km; the dynamics-only source is negative for x = −2.1 to −0.1 km ("slightly upstream of the hill crest").
- Gaussian hills (Barstad and Smith 2005 Fig. 1 style): precipitation at the upslope point, peak and downslope point, normalised by the raw upslope value, for H̃ = N H_w/U and τ̃ = Uτ/a in 0..2.5. It falls with both, equals 1.00 at (0, 0), and the downslope point is essentially dry until τ̃ reaches about 1 (water spilled over the crest). I did not have the paper's contour values to compare numbers, so this is qualitative; my "half-width" a is the e-folding radius of `exp(−r²/a²)`.
- Rotating the wind and the map by 90 degrees gives the same field to 4e-16.

Figure: `docs/evidence/island/climate/ref/lt_ref.jpg`.

## Conventions the C kernel shares

- Forward FFT `e^{−i}`, inverse `e^{+i}/N²`; `k = 2π j/(N dx)` with `j` in `[−N/2, N/2)`.
- The map is zero-padded to `2n × 2n`, **centred**.
- The Nyquist row and column of P̂ are zeroed so the spectrum is exactly Hermitian (the C kernel then uses real-pair packing and half the columns).
- Output P in mm/h; qc in kg m⁻² from `q̂_c = τ_c Ŝ_dyn/(1 + iστ_c)`, `Ŝ_dyn = C_w iσ ĥ/(1 − i m H_w)`.
- `|σ| < 1e-12` gives zero transfer.
