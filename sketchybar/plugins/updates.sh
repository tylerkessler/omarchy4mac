#!/usr/bin/env bash
# Update badge: how many Homebrew packages are outdated. Hidden at zero.
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/displays.sh"
source "$CONFIG_DIR/plugins/cache.sh"

# `brew outdated` is a multi-second Ruby run: at most once every 6 h, one copy at a time (a forced
# `sketchybar --update` loop once stacked 14 of them); wake and display events reuse the count.
outdated() { /opt/homebrew/bin/brew outdated --quiet | wc -l | tr -d ' '; }
COUNT="$(cached updates 21600 outdated)"
if [ "${COUNT:-0}" -gt 0 ]; then
  center_item "$NAME" icon="󰚰" icon.color="$ORANGE" label="$COUNT" label.color="$FG"
else
  sketchybar --set "$NAME" drawing=off
fi
