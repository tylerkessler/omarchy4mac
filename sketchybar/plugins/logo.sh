#!/usr/bin/env bash
# Omarchy logo status (tyler-os #1418): still violet when no agent works, sunset colours with a pulse while one does.
# The motion is driven by agent_status.sh on the agents item's update. This script only paints the resting colour on wake
# and on a forced update, so the logo is never left on a stale colour. No glow, no shadow, no polling of its own.

source "$CONFIG_DIR/colors.sh"
COLOR="${SUN_4:-$ACCENT}"   # calm violet; light themes (no SUN_4) keep the theme accent
sketchybar --set "$NAME" icon.color="$COLOR"
