#!/usr/bin/env bash
# One digit for the focused AeroSpace workspace (tyler-os #1161).
# $FOCUSED_WORKSPACE is set by the aerospace_workspace_change trigger.

source "$CONFIG_DIR/colors.sh"

# A hung AeroSpace must not leave this script waiting forever: 1 s limit (macOS has no `timeout`).
FOCUSED="${FOCUSED_WORKSPACE:-$(/usr/bin/perl -e 'alarm 1; exec @ARGV' /opt/homebrew/bin/aerospace list-workspaces --focused 2>/dev/null)}"

# Ctrl+Left/Right switches native macOS Spaces, which AeroSpace never reports.
# space_change carries the new Space number in $INFO ({"display-1": 2}, per display).
# Native Space 1 is where AeroSpace lives (and what SketchyBar reports at every reload), so keep AeroSpace's answer there.
if [ "$SENDER" = "space_change" ]; then
  NATIVE="$(printf '%s' "$INFO" | sed -n 's/.*"display-[0-9]*"[^0-9]*\([0-9][0-9]*\).*/\1/p' | head -1)"
  [ -n "$NATIVE" ] && [ "$NATIVE" != "1" ] && FOCUSED="$NATIVE"
fi
[ -n "$FOCUSED" ] || exit 0

# The desktop's own sunset step, orange (1) -> violet (5) (Tyler, 2026-10-28).
# live_vibe.sh exports SPACE_1..5 via colors.sh; light themes skip it, so fall back to the theme accent.
_ACC_VAR="SPACE_$FOCUSED"
SPACE_ACC="${!_ACC_VAR:-$ACCENT}"
SPACE_GLOW="0x80${SPACE_ACC:4}"

SPACE_HALO="0x59${SPACE_ACC:4}"

# The whole left island wears the desktop's colour: digit pill, app name, separator, hairline and glow.
# front_app.sh only swaps the icon and name, so the colour set here sticks across app switches.
sketchybar --set "$NAME" \
  icon="$FOCUSED" \
  background.drawing=on \
  background.color="$SPACE_ACC" \
  icon.color="$BG" \
  icon.shadow.drawing=on \
  icon.shadow.distance=4 \
  icon.shadow.color="$SPACE_GLOW" \
  --set front_app icon.color="$SPACE_ACC" label.color="$SPACE_ACC" \
                  icon.shadow.color="$SPACE_HALO" label.shadow.drawing=on label.shadow.distance=2 label.shadow.color="$SPACE_HALO" \
  --set space_sep icon.color="$SPACE_ACC" icon.shadow.color="$SPACE_GLOW" \
  --set vibe_left background.border_color="$SPACE_ACC" background.shadow.color="$SPACE_HALO"
