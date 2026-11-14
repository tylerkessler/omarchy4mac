#!/usr/bin/env bash
# Omarchy logo (tyler-os #1418, #1425): a still yellow-orange sun, the left anchor of the bar's sunset gradient.
# Paints on wake and on a forced update. No motion, no glow, no shadow, no polling of its own.

source "$CONFIG_DIR/colors.sh"
COLOR="${SUN_LOGO:-$ACCENT}"   # the sun; light themes (no SUN_LOGO) keep the theme accent
sketchybar --set "$NAME" icon.color="$COLOR"
