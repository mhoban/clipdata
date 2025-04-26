#!/usr/bin/env bash

function yn {
  while true; do
    read -p "$* [y/n]: " yn
    case $yn in
      [Yy]*) return 0  ;;  
      [Nn]*) return  1 ;;
    esac
  done
}

cd /Users/pristineseas/Documents/clipdata

exiftool=$(which exiftool)
if [[ -z "$exiftool" ]]; then
  echo "exiftool not found"
  exit 1
fi

read -p 'Drag qinsy file here and then hit enter: ' qinsy
read -p 'Drag directory containing video files here and hit enter: ' vids
read -p 'Enter qinsy file time offset in hh:mm:ss format (hit enter for no offset): ' qinsy_offset
read -p 'Enter video file time offset in hh:mm:ss format (hit enter for no offset): ' video_offset
yn "Save dive profiles for each video?" && profile="-p" || profile=""

qinsy_offset=${qinsy_offset:-"00:00:00"}
video_offset=${video_offset:-"00:00:00"}

 ./clipdata.R --output "${vids}/video_metadata.csv" --qinsy-offset "$qinsy_offset" --video-offset "$video_offset" $profile "$qinsy" "$vids"/*.MOV
