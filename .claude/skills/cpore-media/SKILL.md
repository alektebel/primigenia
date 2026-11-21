---
name: cpore-media
description: Video and image recipes for Primigenia (cpore) — look at reference videos as frame sheets, record game clips with software GL, build side-by-side comparison clips, and measure reference footage. Use when the owner shares a video, when comparing our motion with a reference, or when making clips for review or devlogs.
---

# Media recipes (cpore)

Claude cannot play video directly: turn it into frame sheets and read the images. FFmpeg is installed (`/usr/bin/ffmpeg`).

## Where references live
`~/Desarrollo/cpore-refs/videos/` (outside the repo, never commit). Copy new owner videos there from `~/Descargas/` with a descriptive name and add a row to `docs/RESOURCES.md`.

## Look at a video
```sh
ffprobe -v error -show_entries format=duration:stream=width,height -of compact in.mp4
# 1 frame per second, tiled
ffmpeg -v error -y -i in.mp4 -vf "fps=1,scale=320:-1,tile=4x3" -frames:v 1 sheet.jpg
# a short section at 6 fps, cropped to the subject (crop=w:h:x:y)
ffmpeg -v error -y -ss 7 -t 2 -i in.mp4 -vf "crop=576:400:0:340,fps=6,tile=3x4" -frames:v 1 detail.jpg
```
Write sheets to the session scratchpad, then Read them.

## Record our game (software GL only, never the GPU; recipe not yet verified with `--script`, the scorecard agent will confirm)
```sh
LIBGL_ALWAYS_SOFTWARE=1 timeout 300 nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" \
  godot --rendering-driver opengl3 --fixed-fps 30 --resolution 1280x720 --path godot \
  --write-movie /path/out.avi --script res://devtools/tools/<capture>.gd -- <args>
ffmpeg -v error -y -i /path/out.avi -c:v libx264 -crf 23 -pix_fmt yuv420p out.mp4
```

## Side-by-side (reference | ours)
```sh
ffmpeg -v error -y -i ref.mp4 -i ours.mp4 -filter_complex \
 "[0:v]scale=-2:720,drawtext=text='reference':x=20:y=20:fontsize=36:fontcolor=white[a];\
  [1:v]scale=-2:720,drawtext=text='ours':x=20:y=20:fontsize=36:fontcolor=white[b];[a][b]hstack" \
 -an -t 8 side.mp4
```
The scorecard branch adds `tools/loco/sidebyside.sh`. Output clips containing reference footage go to `/home/diego/Desarrollo/cpore-wt/_agent/loco-clips/`, never the repo.

## Blind A/B for the owner
Two unlabelled clips (previous build vs new), randomised left/right; the owner picks the better motion in the tracker. Keep the label → build mapping out of the page until after the vote.

## Measuring reference footage
- Quick: eyeball keypoints (head, shoulders, hips, hands, feet) on side-view frames; mark values as estimates.
- Proper (trial, tracker V1): SAM 2 tracking + SuperAnimal (DeepLabCut) keypoints. Heavy models: ask the owner before using the GPU.

## Later (see docs/RESOURCES.md)
LosslessCut for quick trims, Real-ESRGAN for upscaling, Demucs/DeepFilterNet if we record real sounds.
