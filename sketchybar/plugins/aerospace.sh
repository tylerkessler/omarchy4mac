#!/usr/bin/env bash
# Highlight the focused AeroSpace workspace.
# Workspace id is derived from $NAME (e.g. "space.3" → "3").
# $FOCUSED_WORKSPACE is set by the aerospace_workspace_change trigger.

source "$CONFIG_DIR/colors.sh"

SID="${NAME#space.}"
# A hung AeroSpace must not leave this script waiting forever: 1 s limit (macOS has no `timeout`).
FOCUSED="${FOCUSED_WORKSPACE:-$(/usr/bin/perl -e 'alarm 1; exec @ARGV' /opt/homebrew/bin/aerospace list-workspaces --focused 2>/dev/null)}"

# Ctrl+Left/Right switches native macOS Spaces, which AeroSpace never reports.
# space_change carries the new Space number in $INFO ({"display-1": 2}, per display).
if [ "$SENDER" = "space_change" ]; then
  FOCUSED="$(printf '%s' "$INFO" | sed -n 's/.*"display-[0-9]*"[^0-9]*\([0-9][0-9]*\).*/\1/p' | head -1)"
fi

# This desktop's own sunset step, orange (1) -> violet (5), all different (Tyler, 2026-10-28).
# live_vibe.sh exports SPACE_1..5 + _DIM via colors.sh; light themes skip it, so fall back to the theme accent.
_ACC_VAR="SPACE_$SID"; _DIM_VAR="SPACE_${SID}_DIM"
SPACE_ACC="${!_ACC_VAR:-$ACCENT}"
SPACE_DIM="${!_DIM_VAR:-${SOFT:-$COMMENT}}"
SPACE_GLOW="0x80${SPACE_ACC:4}"

if [ "$SID" = "$FOCUSED" ]; then
  sketchybar --set "$NAME" \
    background.drawing=on \
    background.color="$SPACE_ACC" \
    icon.color="$BG" \
    icon.shadow.drawing=on \
    icon.shadow.distance=4 \
    icon.shadow.color="$SPACE_GLOW"
else
  sketchybar --set "$NAME" \
    background.drawing=off \
    icon.color="$SPACE_DIM" \
    icon.shadow.drawing=off
fi
