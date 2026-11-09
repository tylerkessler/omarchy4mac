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

# Only the digit chip wears the desktop's colour. The outline, divider and app name stay fixed in
# sketchybarrc (violet outline, quiet divider, light type like the clock) so the left island matches the right pill (tyler-os #1336).
sketchybar --set "$NAME" \
  icon="$FOCUSED" \
  background.drawing=on \
  background.color="$SPACE_ACC" \
  icon.color="$BG" \
  icon.shadow.drawing=on \
  icon.shadow.distance=4 \
  icon.shadow.color="$SPACE_GLOW"
