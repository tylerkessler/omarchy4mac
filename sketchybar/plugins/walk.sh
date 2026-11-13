#!/usr/bin/env bash
# Walk pill: today's miles, or the live walk (tyler-os #1394). Click opens the control panel.
# 45 s tick. Reads Digit GET /api/walk or walks.jsonl — never CoreLocation.
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/lib/pill_item.sh"

LABEL="$(python3 "$CONFIG_DIR/lib/walk_data.py" label)"
if [ -n "$LABEL" ]; then pill_show "$NAME" "$LABEL"; else sketchybar --set "$NAME" drawing=off; fi
