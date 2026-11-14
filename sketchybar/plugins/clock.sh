#!/usr/bin/env bash
source "$CONFIG_DIR/colors.sh"

LABEL="$(date '+%a  %-I:%M %p')"
ICON="󰥔"
# The icon walks the sunset through the day (tyler-os #1161): morning orange, midday pink,
# afternoon magenta, evening orchid, night violet. Light themes fall back to pink.
HOUR=$((10#$(date +%H)))
if   [ "$HOUR" -ge 6 ]  && [ "$HOUR" -lt 10 ]; then ICON_COLOR="$SPACE_1"
elif [ "$HOUR" -ge 10 ] && [ "$HOUR" -lt 14 ]; then ICON_COLOR="$SPACE_2"
elif [ "$HOUR" -ge 14 ] && [ "$HOUR" -lt 17 ]; then ICON_COLOR="$SPACE_3"
elif [ "$HOUR" -ge 17 ] && [ "$HOUR" -lt 20 ]; then ICON_COLOR="$SPACE_4"
else ICON_COLOR="$SPACE_5"; fi
ICON_COLOR="${ICON_COLOR:-${PINK:-$MAGENTA}}"

source "$CONFIG_DIR/plugins/displays.sh"

if [ "$BUILTIN" != "-" ]; then
  sketchybar --set clock_right drawing=on associated_display="$BUILTIN" \
                   icon="$ICON" icon.color="$ICON_COLOR" label="$LABEL" label.color="$FG"
else
  sketchybar --set clock_right drawing=off
fi

if [ "$OTHERS" != "-" ]; then
  sketchybar --set clock drawing=on associated_display="$OTHERS" \
                   icon="$ICON" icon.color="$ICON_COLOR" label="$LABEL" label.color="$FG"
else
  sketchybar --set clock drawing=off
fi
