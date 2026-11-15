# Idol photo-to-3D evaluation (G74)

Standalone, review-only asset tooling. No integration into studio, stage or core.

Upstream: https://github.com/speridlabs/idol-sdk at
`8db700349a5570aac390e4780fa32e3eed6b587a` (Apache-2.0).
Weights: https://huggingface.co/speridlabs/idol (Apache-2.0).
The required DINOv3 and FLUX.2-dev encoders have separate gated terms; the
configured Hugging Face account currently receives HTTP 403 for both.
Real inference and its quality/VRAM/timing evidence depend on that access.

Environment: `/home/diego/Desarrollo/cpore-wt/_agent/idol-venv`.
Code, caches and weights: `/home/diego/Desarrollo/cpore-wt/_agent/models/`.
No weights or environment belong in this repository.
