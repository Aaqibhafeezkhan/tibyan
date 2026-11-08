#!/bin/zsh
# compose raw clips onto brand background, 1920x1080, silent
set -e
R=/Users/ahmed/Desktop/Tibyan-MSStore/video/raw
O=/Users/ahmed/Desktop/Tibyan-MSStore/video/tibyan-trailer-1920x1080.mp4
BG=/Users/ahmed/Projects/Tibyan-Quran-App/docs/brand/store/templates/mac/2880x1800/layers/background.png
L=$R/list.txt; : > $L
for n in t1_home t2_mushaf t3_tafsir t4_listen t5_khatma t6_tasbih; do
  [ -f $R/$n.mp4 ] || { echo missing $n; exit 1; }
  ffmpeg -y -v error -loop 1 -i $BG -i $R/$n.mp4 -filter_complex \
   "[0]scale=1920:1200:flags=lanczos,crop=1920:1080[b];[1]fps=30,scale=1760:-2:flags=lanczos,format=yuv420p[v];[b][v]overlay=(W-w)/2:(H-h)/2:shortest=1,fade=t=in:d=0.3,format=yuv420p" \
   -an -r 30 -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p $R/seg_$n.mp4
  echo "file '$R/seg_$n.mp4'" >> $L
done
ffmpeg -y -v error -f concat -safe 0 -i $L -c copy -an -movflags +faststart $O
ffprobe -v error -show_entries format=duration,size:stream=width,height,codec_name,r_frame_rate,pix_fmt $O
