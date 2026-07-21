#!/bin/bash

set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "usage: $0 SOURCE_DIR TARGET_DIR [RELATIVE_PATH_REGEX]" >&2
  exit 2
fi

source_root=${1%/}
target_root=${2%/}
path_filter=${3:-'.*'}

if [ ! -d "$source_root" ]; then
  echo "source directory does not exist: $source_root" >&2
  exit 2
fi

if [ "$source_root" = "$target_root" ]; then
  echo "source and target directories must differ" >&2
  exit 2
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required" >&2
  exit 2
fi

staging_root="$target_root/.staging-destroyed"
mkdir -p "$staging_root"

processed=0
skipped=0

render_frame() {
  local source_png=$1
  local canvas_w=$2
  local canvas_h=$3
  local pos_x=$4
  local pos_y=$5
  local output_png=$6

  magick -size "${canvas_w}x${canvas_h}" canvas:none \
    "$source_png" -geometry "+${pos_x}+${pos_y}" -composite \
    "$output_png"
}

make_sheet() {
  local canvas_w=$1
  local canvas_h=$2
  local frames_dir=$3
  local output_png=$4
  local sheet_w=$((canvas_w * 3))
  local sheet_h=$((canvas_h * 2))

  magick -size "${sheet_w}x${sheet_h}" canvas:none \
    "$frames_dir/frame-01.png" -geometry +0+0 -composite \
    "$frames_dir/frame-02.png" -geometry "+${canvas_w}+0" -composite \
    "$frames_dir/frame-03.png" -geometry "+$((canvas_w * 2))+0" -composite \
    "$frames_dir/frame-04.png" -geometry "+0+${canvas_h}" -composite \
    "$frames_dir/frame-05.png" -geometry "+${canvas_w}+${canvas_h}" -composite \
    "$frames_dir/frame-06.png" -geometry "+$((canvas_w * 2))+${canvas_h}" -composite \
    "$output_png"
}

validate_destroyed() {
  local source_png=$1
  local gray_png=$2
  local source_w=$3
  local source_h=$4
  local base_x=$5
  local base_y=$6
  local canvas_w=$7
  local canvas_h=$8
  local gif_path=$9
  local sheet_path=${10}
  local frames_dir=${11}
  local validation_dir=${12}

  local gif_frames
  local gif_size
  local sheet_size
  local metric

  gif_frames=$(identify "$gif_path" | wc -l | tr -d ' ')
  gif_size=$(identify -format '%wx%h' "${gif_path}[0]")
  sheet_size=$(identify -format '%wx%h' "$sheet_path")

  if [ "$gif_frames" != "6" ]; then
    echo "expected 6 GIF frames, found $gif_frames: $gif_path" >&2
    return 1
  fi

  if [ "$gif_size" != "${canvas_w}x${canvas_h}" ]; then
    echo "unexpected GIF canvas $gif_size: $gif_path" >&2
    return 1
  fi

  if [ "$sheet_size" != "$((canvas_w * 3))x$((canvas_h * 2))" ]; then
    echo "unexpected sprite-sheet canvas $sheet_size: $sheet_path" >&2
    return 1
  fi

  magick "${gif_path}[0]" \
    -crop "${source_w}x${source_h}+${base_x}+${base_y}" +repage \
    "$validation_dir/neutral-crop.png"
  metric=$(magick compare -metric AE \
    "$source_png" "$validation_dir/neutral-crop.png" null: 2>&1 || true)
  rm -f "$validation_dir/neutral-crop.png"
  if [ "$metric" != "0 (0)" ]; then
    echo "neutral frame differs from source ($metric): $gif_path" >&2
    return 1
  fi

  magick "$frames_dir/frame-06.png" \
    -crop "${source_w}x${source_h}+${base_x}+${base_y}" +repage \
    "$validation_dir/final-crop.png"
  metric=$(magick compare -metric AE \
    "$gray_png" "$validation_dir/final-crop.png" null: 2>&1 || true)
  rm -f "$validation_dir/final-crop.png"
  if [ "$metric" != "0 (0)" ]; then
    echo "final frame differs from expected grayscale ($metric): $gif_path" >&2
    return 1
  fi

  metric=$(magick compare -metric AE \
    "$frames_dir/frame-05.png" "$frames_dir/frame-06.png" null: 2>&1 || true)
  if [ "$metric" != "0 (0)" ]; then
    echo "final two frames are not identical ($metric): $gif_path" >&2
    return 1
  fi
}

while IFS= read -r -d '' source_png; do
  relative_path=${source_png#"$source_root"/}

  if ! [[ "$relative_path" =~ $path_filter ]]; then
    continue
  fi

  relative_dir=$(dirname "$relative_path")
  filename=$(basename "$source_png")
  sprite_name=${filename%.*}
  sprite_dir="$target_root/$relative_dir/$sprite_name"
  final_dir="$sprite_dir/destroyed"
  destroyed_gif="$final_dir/${sprite_name}-destroyed.gif"
  destroyed_sheet="$final_dir/${sprite_name}-destroyed-spritesheet.png"

  if [ -f "$destroyed_gif" ] && [ -f "$destroyed_sheet" ] && \
     [ "$(find "$final_dir/frames" -maxdepth 1 -type f -name 'frame-*.png' 2>/dev/null | wc -l | tr -d ' ')" = "6" ]; then
    echo "SKIP|$relative_path"
    skipped=$((skipped + 1))
    continue
  fi

  if [ -e "$final_dir" ]; then
    echo "refusing to overwrite incomplete output: $final_dir" >&2
    exit 1
  fi

  read -r source_w source_h <<EOF
$(identify -format '%w %h' "$source_png")
EOF

  unit_x=$(((source_w + 31) / 64))
  unit_y=$(((source_h + 64) / 128))
  [ "$unit_x" -ge 1 ] || unit_x=1
  [ "$unit_y" -ge 1 ] || unit_y=1

  pad_x=$((unit_x * 3 + 2))
  pad_y=$((unit_y * 2 + 1))
  canvas_w=$((source_w + pad_x * 2))
  canvas_h=$((source_h + pad_y * 2))
  base_x=$pad_x
  base_y=$pad_y

  stage_dir="$staging_root/$relative_dir/${sprite_name}.work.$$"
  frames_dir="$stage_dir/frames"
  validation_dir="$stage_dir/.validation"
  gray_png="$stage_dir/.grayscale.png"
  mkdir -p "$frames_dir" "$validation_dir"

  magick "$source_png" -colorspace Gray -colorspace sRGB "$gray_png"

  render_frame "$source_png" "$canvas_w" "$canvas_h" \
    "$base_x" "$base_y" "$frames_dir/frame-01.png"
  render_frame "$source_png" "$canvas_w" "$canvas_h" \
    "$((base_x - unit_x))" "$((base_y - unit_y))" "$frames_dir/frame-02.png"
  render_frame "$source_png" "$canvas_w" "$canvas_h" \
    "$((base_x + unit_x))" "$((base_y + unit_y))" "$frames_dir/frame-03.png"
  render_frame "$gray_png" "$canvas_w" "$canvas_h" \
    "$((base_x - unit_x))" "$((base_y + unit_y))" "$frames_dir/frame-04.png"
  render_frame "$gray_png" "$canvas_w" "$canvas_h" \
    "$base_x" "$base_y" "$frames_dir/frame-05.png"
  render_frame "$gray_png" "$canvas_w" "$canvas_h" \
    "$base_x" "$base_y" "$frames_dir/frame-06.png"

  destroyed_gif_stage="$stage_dir/${sprite_name}-destroyed.gif"
  destroyed_sheet_stage="$stage_dir/${sprite_name}-destroyed-spritesheet.png"

  magick -dispose background \
    -delay 8 "$frames_dir/frame-01.png" \
    -delay 5 "$frames_dir/frame-02.png" \
    -delay 5 "$frames_dir/frame-03.png" \
    -delay 7 "$frames_dir/frame-04.png" \
    -delay 10 "$frames_dir/frame-05.png" \
    -delay 30 "$frames_dir/frame-06.png" \
    -loop 1 \
    "$destroyed_gif_stage"

  make_sheet "$canvas_w" "$canvas_h" "$frames_dir" "$destroyed_sheet_stage"
  validate_destroyed "$source_png" "$gray_png" "$source_w" "$source_h" \
    "$base_x" "$base_y" "$canvas_w" "$canvas_h" \
    "$destroyed_gif_stage" "$destroyed_sheet_stage" "$frames_dir" "$validation_dir"

  rm -f "$gray_png"
  rmdir "$validation_dir" 2>/dev/null || true
  mkdir -p "$sprite_dir"
  mv "$stage_dir" "$final_dir"

  echo "DONE|$relative_path|source=${source_w}x${source_h}|canvas=${canvas_w}x${canvas_h}"
  processed=$((processed + 1))
done < <(find "$source_root" -type f -iname '*.png' -print0 | sort -z)

find "$staging_root" -depth -type d -empty -delete 2>/dev/null || true
echo "SUMMARY|processed=$processed|skipped=$skipped"
