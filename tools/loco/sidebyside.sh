#!/bin/sh
# Side-by-side clip: tools/loco/sidebyside.sh <reference.mp4> <ours.mp4> <out.mp4> [hash]
# Same height, hstack, labels "reference" / "ours <hash>". The output belongs outside the repo (/home/diego/Desarrollo/cpore-wt/_agent/loco-clips/).
set -eu
ref="$1"; ours="$2"; out="$3"; hash="${4:-$(git rev-parse --short HEAD 2>/dev/null || echo dev)}"
H=540
# REF_START=seconds skips the reference intro (gorilla clip: the walk starts at 6)
SS=""; [ -n "${REF_START:-}" ] && SS="-ss $REF_START"
# CROP_REF="w:h:x:y" crops the reference first (a phone screen recording: the clip sits in the middle of the screen)
CROP=""; [ -n "${CROP_REF:-}" ] && CROP="crop=$CROP_REF,"
FONT=$(fc-match -f '%{file}' monospace 2>/dev/null || echo /usr/share/fonts/TTF/DejaVuSansMono.ttf)
nice -n 10 ffmpeg -y -loglevel error $SS -i "$ref" -i "$ours" -filter_complex \
 "[0:v]${CROP}scale=-2:$H,setsar=1,drawtext=fontfile=$FONT:text='reference':x=12:y=12:fontsize=26:fontcolor=white:box=1:boxcolor=black@0.6[a];\
[1:v]scale=-2:$H,setsar=1,drawtext=fontfile=$FONT:text='ours $hash':x=12:y=12:fontsize=26:fontcolor=white:box=1:boxcolor=black@0.6[b];\
[a][b]hstack=inputs=2:shortest=1[v]" -map "[v]" -an -c:v libx264 -pix_fmt yuv420p -crf 23 "$out"
