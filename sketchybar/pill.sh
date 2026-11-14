#!/usr/bin/env bash
# One pill design for every island on the bar (tyler-os #1381, Nov 13 2026).
# Same shape, padding and corner radius everywhere; white icon and text; each pill only changes its ACCENT
# (hairline border of that hue). No shadow, no glow, no solid accent fill: a crisp solid outline (tyler-os #1418).
# Same look in every state, condensed included.
# Python-drawn pills (tyler-os coach/cu_bar.py, coach/session_md.py) use the same numbers.
PILL_RADIUS=14
PILL_HEIGHT=28
PILL_BORDER=2

# pill_args ACCENT -> the sketchybar properties of one pill. ACCENT is a 0xAARRGGBB colour; empty = quiet outline.
pill_args() {
  local c="$1"
  printf 'background.color=%s background.corner_radius=%s background.height=%s background.border_width=%s ' \
    "${PLUM:-$BG_PILL}" "$PILL_RADIUS" "$PILL_HEIGHT" "$PILL_BORDER"
  printf 'background.shadow.drawing=off '
  printf 'background.border_color=%s' "${c:-$OVERLAY}"
}

# popup_args ACCENT -> the properties of a popup panel under a pill (same plum fill, accent outline, no shadow; tyler-os #1419).
popup_args() {
  printf 'popup.background.color=%s popup.background.corner_radius=12 popup.background.border_width=%s popup.background.border_color=%s ' \
    "${PLUM:-$BG_PILL}" "$PILL_BORDER" "${1:-$OVERLAY}"
  printf 'popup.background.shadow.drawing=off popup.blur_radius=0 popup.y_offset=6'
}
