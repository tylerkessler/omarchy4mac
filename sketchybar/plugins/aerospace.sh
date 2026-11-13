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

# Just the number, no chip: halfway between the desktop's own sunset step (orange 1 -> violet 5) and white, semi-transparent,
# so the bar behind it bleeds through (Tyler, 2026-11-13). live_vibe.sh exports SPACE_1_TXT..5_TXT; light themes skip it
# and the digit keeps the theme's text colour.
_TXT_VAR="SPACE_${FOCUSED}_TXT"
sketchybar --set "$NAME" \
  icon="$FOCUSED" \
  background.drawing=off \
  icon.color="${!_TXT_VAR:-$FG}" \
  icon.shadow.drawing=off
