#!/usr/bin/env bash
# Touch-grass pill: 2+ hours of active Mac use without a break (tyler-os #1381). Every 60 s it reads HID idle time (ioreg, cheap);
# 10+ minutes idle, or a lid-shut/sleep gap between ticks, resets the timer. Click = snooze 15 minutes.
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/lib/pill_item.sh"

IDLE="$(/usr/sbin/ioreg -c IOHIDSystem | /usr/bin/awk '/HIDIdleTime/{print $NF; exit}')"
IFS='|' read -r SHOW LABEL <<<"$(python3 "$CONFIG_DIR/lib/extras.py" grass "${IDLE:-0}")"
if [ "$SHOW" = "1" ]; then pill_show "$NAME" "$LABEL"; else sketchybar --set "$NAME" drawing=off; fi
