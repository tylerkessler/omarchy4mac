#!/usr/bin/env bash
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icon_map.sh"

if [ "$SENDER" = "front_app_switched" ]; then
  __icon_map "$INFO"
  sketchybar --set "$NAME" \
    icon="$icon_result" \
    icon.drawing=on \
    icon.font="sketchybar-app-font:Regular:16.0" \
    label="$INFO"
  # Colour comes from aerospace.sh: the focused desktop's sunset step (tyler-os #1161).
fi
