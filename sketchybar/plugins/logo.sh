#!/usr/bin/env bash
# Omarchy logo drifts through the TKOS sunset with a faint glow (tyler-os #1161).
# One step every 2 min (update_freq), orange -> violet -> back, 16 min a lap.
# No running animation: one 1 s fade per step, nothing between.

source "$CONFIG_DIR/colors.sh"

# Light themes skip live_vibe.sh: keep the theme accent, no drift.
if [ -z "$SPACE_1" ]; then
  sketchybar --set "$NAME" icon.color="$ACCENT" icon.shadow.color="$GLOW"
  exit 0
fi

STOPS=("$SPACE_1" "$SPACE_2" "$SPACE_3" "$SPACE_4" "$SPACE_5" "$SPACE_4" "$SPACE_3" "$SPACE_2")
STEP=$(( ($(date +%s) / 120) % ${#STOPS[@]} ))
COLOR="${STOPS[$STEP]}"
# 25% alpha of the same hue: a halo you notice only when you look for it.
HALO="0x40${COLOR:4}"

sketchybar --animate sin 60 --set "$NAME" icon.color="$COLOR" icon.shadow.color="$HALO"
