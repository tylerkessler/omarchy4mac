#!/usr/bin/env bash
source "$CONFIG_DIR/colors.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"
CHARGING="$(pmset -g batt | grep -c 'AC Power')"

[ -z "$PERCENTAGE" ] && exit 0

if [ "$CHARGING" -gt 0 ]; then
  # Charging: fill the battery one frame per second, then start over.
  FRAMES=(󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅)
  ICON="${FRAMES[$(( $(date +%s) % ${#FRAMES[@]} ))]}"
  COLOR="$GREEN"
  FREQ=1
else
  case "$PERCENTAGE" in
    100|9[0-9]) ICON="󰁹"; COLOR="$GREEN" ;;
    [7-8][0-9]) ICON="󰂀"; COLOR="$GREEN" ;;
    [4-6][0-9]) ICON="󰁾"; COLOR="$YELLOW" ;;
    [2-3][0-9]) ICON="󰁼"; COLOR="$ORANGE" ;;
    *)          ICON="󰂃"; COLOR="$RED" ;;
  esac
  FREQ=10
fi

# Watts in from the charger and out to the system (Apple Silicon telemetry, mW).
TELEMETRY="$(ioreg -rn AppleSmartBattery | grep -o '"System\(PowerIn\|Load\)"=[0-9]*')"
W_IN="$(echo "$TELEMETRY" | awk -F= '/PowerIn/ {printf "%.0f", $2/1000}')"
W_OUT="$(echo "$TELEMETRY" | awk -F= '/Load/ {printf "%.0f", $2/1000}')"

# Each power number is its own bar item so it can carry its own colour, and they
# read left to right into the battery: +in (mint)  -out (orange)  >>> net (gold).
# The chevrons march toward the battery while it fills and point away (red) while
# it drains. They animate at the same 1s tick as the charging icon.
IN_LABEL=""; OUT_LABEL=""; BATT_LABEL=""; BATT_COLOR="$YELLOW"
[ -n "$W_IN" ] && [ "$W_IN" -gt 0 ] && IN_LABEL="+${W_IN}W"
[ -n "$W_OUT" ] && OUT_LABEL="-${W_OUT}W"
TICK=$(( $(date +%s) % 3 ))
if [ -n "$W_OUT" ]; then
  W_BATT=$(( ${W_IN:-0} - W_OUT ))
  if [ "$W_BATT" -ge 0 ]; then
    FLOW=("›  " "›› " "›››"); BATT_LABEL="${FLOW[$TICK]} +${W_BATT}W"
  else
    FLOW=("  ‹" " ‹‹" "‹‹‹"); BATT_LABEL="${FLOW[$TICK]} ${W_BATT}W"; BATT_COLOR="$RED"
  fi
fi

shown() { [ -n "$1" ] && echo on || echo off; }

sketchybar --set "$NAME" \
  icon="$ICON" \
  icon.color="$COLOR" \
  label="${PERCENTAGE}%" \
  update_freq="$FREQ" \
  --set power_in   drawing="$(shown "$IN_LABEL")"   label="$IN_LABEL"   label.color="$GREEN" \
  --set power_out  drawing="$(shown "$OUT_LABEL")"  label="$OUT_LABEL"  label.color="$ORANGE" \
  --set power_batt drawing="$(shown "$BATT_LABEL")" label="$BATT_LABEL" label.color="$BATT_COLOR"
