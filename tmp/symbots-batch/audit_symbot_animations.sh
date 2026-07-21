#!/bin/bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 SOURCE_DIR TARGET_DIR MANIFEST_CSV" >&2
  exit 2
fi

source_root=${1%/}
target_root=${2%/}
manifest_path=$3
manifest_tmp="${manifest_path}.tmp.$$"
check_dir=$(mktemp -d)

cleanup() {
  rm -rf "$check_dir"
  rm -f "$manifest_tmp"
}
trap cleanup EXIT

printf '%s\n' \
  'source,source_size,canvas_size,idle_gif,idle_spritesheet,attack_gif,attack_spritesheet,status' \
  > "$manifest_tmp"

checked=0
failures=0

while IFS= read -r -d '' source_png; do
  relative_path=${source_png#"$source_root"/}
  relative_dir=$(dirname "$relative_path")
  filename=$(basename "$source_png")
  sprite_name=${filename%.*}
  sprite_dir="$target_root/$relative_dir/$sprite_name"

  read -r source_w source_h <<EOF
$(identify -format '%w %h' "$source_png")
EOF

  sprite_failed=0
  canvas_w=''
  canvas_h=''

  for mode in idle attack; do
    gif_path="$sprite_dir/$mode/${sprite_name}-${mode}.gif"
    sheet_path="$sprite_dir/$mode/${sprite_name}-${mode}-spritesheet.png"
    frames_dir="$sprite_dir/$mode/frames"

    if [ ! -f "$gif_path" ] || [ ! -f "$sheet_path" ] || [ ! -d "$frames_dir" ]; then
      echo "MISSING|$relative_path|$mode" >&2
      sprite_failed=1
      continue
    fi

    gif_frames=$(identify "$gif_path" | wc -l | tr -d ' ')
    frame_pngs=$(find "$frames_dir" -maxdepth 1 -type f -name 'frame-*.png' | wc -l | tr -d ' ')
    read -r mode_canvas_w mode_canvas_h <<EOF
$(identify -format '%w %h' "${gif_path}[0]")
EOF
    read -r sheet_w sheet_h <<EOF
$(identify -format '%w %h' "$sheet_path")
EOF

    if [ "$gif_frames" != "6" ] || [ "$frame_pngs" != "6" ]; then
      echo "FRAME_COUNT_FAIL|$relative_path|$mode|gif=$gif_frames|png=$frame_pngs" >&2
      sprite_failed=1
    fi

    if [ "$sheet_w" -ne $((mode_canvas_w * 3)) ] || \
       [ "$sheet_h" -ne $((mode_canvas_h * 2)) ]; then
      echo "SHEET_SIZE_FAIL|$relative_path|$mode" >&2
      sprite_failed=1
    fi

    gif_channels=$(identify -format '%[channels]' "${gif_path}[0]")
    sheet_channels=$(identify -format '%[channels]' "$sheet_path")
    frame_channels=$(identify -format '%[channels]' "$frames_dir/frame-01.png")
    case "$gif_channels:$sheet_channels:$frame_channels" in
      *a*:*a*:*a*) ;;
      *)
        echo "ALPHA_FAIL|$relative_path|$mode|$gif_channels:$sheet_channels:$frame_channels" >&2
        sprite_failed=1
        ;;
    esac

    if [ -n "$canvas_w" ] && \
       { [ "$canvas_w" -ne "$mode_canvas_w" ] || [ "$canvas_h" -ne "$mode_canvas_h" ]; }; then
      echo "CANVAS_MISMATCH|$relative_path|$mode" >&2
      sprite_failed=1
    fi
    canvas_w=$mode_canvas_w
    canvas_h=$mode_canvas_h

    base_x=$(((canvas_w - source_w) / 2))
    base_y=$(((canvas_h - source_h) / 2))
    first_crop="$check_dir/${checked}-${mode}.png"
    magick "${gif_path}[0]" \
      -crop "${source_w}x${source_h}+${base_x}+${base_y}" +repage \
      "$first_crop"
    metric=$(magick compare -metric AE "$source_png" "$first_crop" null: 2>&1 || true)
    if [ "$metric" != "0 (0)" ]; then
      echo "SOURCE_DIFF|$relative_path|$mode|$metric" >&2
      sprite_failed=1
    fi
  done

  idle_rel="$relative_dir/$sprite_name/idle/${sprite_name}-idle.gif"
  idle_sheet_rel="$relative_dir/$sprite_name/idle/${sprite_name}-idle-spritesheet.png"
  attack_rel="$relative_dir/$sprite_name/attack/${sprite_name}-attack.gif"
  attack_sheet_rel="$relative_dir/$sprite_name/attack/${sprite_name}-attack-spritesheet.png"

  if [ "$sprite_failed" -eq 0 ]; then
    status=PASS
  else
    status=FAIL
    failures=$((failures + 1))
  fi

  printf '"%s","%sx%s","%sx%s","%s","%s","%s","%s","%s"\n' \
    "$relative_path" "$source_w" "$source_h" "$canvas_w" "$canvas_h" \
    "$idle_rel" "$idle_sheet_rel" "$attack_rel" "$attack_sheet_rel" "$status" \
    >> "$manifest_tmp"
  checked=$((checked + 1))
done < <(find "$source_root" -type f -iname '*.png' -print0 | sort -z)

if [ "$checked" -ne 48 ]; then
  echo "SOURCE_COUNT_FAIL|expected=48|found=$checked" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "AUDIT_FAIL|checked=$checked|failures=$failures" >&2
  exit 1
fi

mv "$manifest_tmp" "$manifest_path"
echo "AUDIT_PASS|checked=$checked|failures=0|manifest=$manifest_path"
