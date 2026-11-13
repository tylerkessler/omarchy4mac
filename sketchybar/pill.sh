#!/usr/bin/env bash
# One pill design for every island on the bar (tyler-os #1381, Nov 13 2026).
# Same shape, padding and corner radius everywhere; white icon and text; each pill only changes its ACCENT
# (hairline border + soft glow of the same hue). No solid accent fill. Same look in every state, condensed included.
# Python-drawn pills (tyler-os coach/cu_bar.py, coach/session_md.py) use the same numbers.
PILL_RADIUS=14
PILL_HEIGHT=28
PILL_BORDER=2
PILL_SHADOW=4

# pill_args ACCENT -> the sketchybar properties of one pill. ACCENT is a 0xAARRGGBB colour; empty = quiet outline.
pill_args() {
  local c="$1"
  printf 'background.color=%s background.corner_radius=%s background.height=%s background.border_width=%s ' \
    "${PLUM:-$BG_PILL}" "$PILL_RADIUS" "$PILL_HEIGHT" "$PILL_BORDER"
  printf 'background.shadow.drawing=on background.shadow.distance=%s ' "$PILL_SHADOW"
  if [ -n "$c" ]; then
    printf 'background.border_color=%s background.shadow.color=0x59%s' "$c" "${c:4}"
  else
    printf 'background.border_color=%s background.shadow.color=0x66000000' "$OVERLAY"
  fi
}
