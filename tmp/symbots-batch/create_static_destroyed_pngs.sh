#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 TARGET_DIR" >&2
  exit 2
fi

target_root=${1%/}
created=0

while IFS= read -r -d '' final_frame; do
  frames_dir=$(dirname "$final_frame")
  destroyed_dir=$(dirname "$frames_dir")
  sprite_dir=$(dirname "$destroyed_dir")
  sprite_name=$(basename "$sprite_dir")
  output_png="$destroyed_dir/${sprite_name}-destroyed.png"
  temp_png="$destroyed_dir/.${sprite_name}-destroyed.work.$$.png"

  if [ -e "$output_png" ]; then
    echo "refusing to overwrite existing output: $output_png" >&2
    exit 1
  fi

  cp "$final_frame" "$temp_png"

  metric=$(magick compare -metric AE "$final_frame" "$temp_png" null: 2>&1 || true)
  if [ "$metric" != "0 (0)" ]; then
    echo "static PNG differs from final frame ($metric): $output_png" >&2
    exit 1
  fi

  channels=$(identify -format '%[channels]' "$temp_png")
  case "$channels" in
    *a*) ;;
    *)
      echo "static PNG lacks transparency: $output_png" >&2
      exit 1
      ;;
  esac

  saturation_max=$(magick "$temp_png" \
    -colorspace HSL -channel G -separate -format '%[fx:maxima]' info:)
  if ! awk -v value="$saturation_max" 'BEGIN { exit !(value <= 0.000001) }'; then
    echo "static PNG is not grayscale: $output_png" >&2
    exit 1
  fi

  mv "$temp_png" "$output_png"
  echo "DONE|${output_png#"$target_root"/}"
  created=$((created + 1))
done < <(find "$target_root" -type f -path '*/destroyed/frames/frame-06.png' -print0 | sort -z)

if [ "$created" -ne 48 ]; then
  echo "expected 48 static PNGs, created $created" >&2
  exit 1
fi

echo "SUMMARY|created=$created"
