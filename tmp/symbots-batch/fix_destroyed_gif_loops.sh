#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 TARGET_DIR" >&2
  exit 2
fi

target_root=${1%/}
fixed=0

while IFS= read -r -d '' gif_path; do
  destroyed_dir=$(dirname "$gif_path")
  frames_dir="$destroyed_dir/frames"
  gif_name=$(basename "$gif_path")
  temp_gif="$destroyed_dir/.${gif_name}.work.$$"

  if [ ! -d "$frames_dir" ]; then
    echo "missing frames directory for $gif_path" >&2
    exit 1
  fi

  magick -dispose background \
    -delay 8 "$frames_dir/frame-01.png" \
    -delay 5 "$frames_dir/frame-02.png" \
    -delay 5 "$frames_dir/frame-03.png" \
    -delay 7 "$frames_dir/frame-04.png" \
    -delay 10 "$frames_dir/frame-05.png" \
    -delay 30 "$frames_dir/frame-06.png" \
    -loop 1 "gif:$temp_gif"

  if [ "$(identify "$temp_gif" | wc -l | tr -d ' ')" != "6" ]; then
    echo "unexpected frame count in $temp_gif" >&2
    exit 1
  fi

  if strings "$temp_gif" | grep -q 'NETSCAPE2.0'; then
    echo "unexpected loop extension in $temp_gif" >&2
    exit 1
  fi

  mv "$temp_gif" "$gif_path"
  fixed=$((fixed + 1))
done < <(find "$target_root" -type f -name '*-destroyed.gif' -print0 | sort -z)

echo "FIXED|destroyed_gifs=$fixed|iterations=1"
