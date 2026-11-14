#!/usr/bin/env bash
# Shared pill look for the YouTube and touch-grass items (tyler-os #1381): same shape, padding and radius as every island,
# white icon and text, only the accent differs (hairline border of that hue, no shadow or glow, never a solid fill).
# pill_item_args ACCENT -> sketchybar properties.   pill_show NAME TEXT -> grow/shrink the label to the text, or condense it.
pill_item_args() {
  local c="$1"
  printf 'background.drawing=on background.color=%s background.corner_radius=14 background.height=28 background.border_width=2 ' "${PLUM:-$BG_PILL}"
  printf 'background.border_color=%s background.shadow.drawing=off ' "$c"
  printf 'icon.color=0xffffffff label.color=0xffffffff icon.shadow.drawing=off padding_left=8 padding_right=0'
}

# Sizes the pill to its text, static (tyler-os #1425): no tween, no scroll; past the cap the text is cut with an ellipsis.
# Condensed (computer-use banner on) keeps the same design but shrinks the label.
pill_show() {
  local name="$1" text="$2" cond=""
  [ "$(python3 "$CONFIG_DIR/lib/extras.py" condensed)" = "1" ] && cond="condensed"
  read -r px chars scrolls <<<"$(python3 "$CONFIG_DIR/lib/extras.py" width "$text" $cond)"
  [ "$scrolls" = 1 ] && text="${text:0:$((chars - 1))}…"
  sketchybar --set "$name" drawing=on label="$text" label.max_chars="$chars" scroll_texts=off label.width="$px"
}
