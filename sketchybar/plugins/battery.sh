#!/usr/bin/env bash
# Battery island: [ 34W ··• ] [ 󰂊 85% ]
#   power_flow  watts + a travelling dot. Charging: charger watts, the dot moves right INTO the battery (mint).
#               On battery: what the Mac is drawing, the dot moves left OUT of the battery (orange).
#               Plugged in but holding (full or at the charge limit): charger watts, still dots (dim).
#   battery     level glyph tinted by charge, and the percent.
# One ioreg read per run. It runs every 2 s while power moves (the dot needs the tick) and every 30 s while holding.
# Click: a terminal with `tyler battery watch` (every device, last report, 24 h sparklines; tyler-os #1150).
source "$CONFIG_DIR/colors.sh"
MINT="${MINT:-$GREEN}"; GOLD="${GOLD:-$YELLOW}"; DIM="${DIM:-$COMMENT}"; SUN_1="${SUN_1:-$ORANGE}"   # light themes skip live_vibe.sh

IO="$(/usr/sbin/ioreg -rn AppleSmartBattery)"
num() { printf '%s\n' "$IO" | grep -o "\"$1\"[ =]*[0-9]*" | head -1 | grep -o '[0-9]*$'; }
is_yes() { printf '%s\n' "$IO" | grep -q "\"$1\" = Yes"; }

CUR="$(num CurrentCapacity)"; MAX="$(num MaxCapacity)"
[ -z "$CUR" ] || [ -z "$MAX" ] || [ "$MAX" -eq 0 ] && exit 0
PCT=$(( CUR * 100 / MAX ))
W_IN=$(( ($(num SystemPowerIn || echo 0) + 500) / 1000 ))
W_OUT=$(( ($(num SystemLoad || echo 0) + 500) / 1000 ))

LEVEL=$(( PCT >= 95 ? 10 : PCT / 10 ))
if is_yes IsCharging; then STATE=charging; elif is_yes ExternalConnected; then STATE=holding; else STATE=draining; fi

# Level glyphs 0..10 (Hack Nerd Font), charging set has the bolt
PLAIN=(󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
BOLT=(󰢟 󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅)
if [ "$PCT" -ge 60 ]; then LEVEL_COLOR="$MINT"; elif [ "$PCT" -ge 30 ]; then LEVEL_COLOR="$GOLD"
elif [ "$PCT" -ge 15 ]; then LEVEL_COLOR="$SUN_1"; else LEVEL_COLOR="$RED"; fi

TICK=$(( $(date +%s) / 2 % 3 ))
case "$STATE" in
  charging) FRAMES=("•··" "·•·" "··•"); WATTS="$W_IN"; FLOW_COLOR="$MINT"; ICON="${BOLT[$LEVEL]}"; FREQ=2 ;;
  draining) FRAMES=("··•" "·•·" "•··"); WATTS="$W_OUT"; FLOW_COLOR="$SUN_1"; ICON="${PLAIN[$LEVEL]}"; FREQ=2 ;;
  *)        FRAMES=("···" "···" "···"); WATTS="$W_IN"; FLOW_COLOR="$DIM"; ICON="${BOLT[$LEVEL]}"; FREQ=30 ;;
esac

FLOW_DRAW=on
[ "$WATTS" -le 0 ] && FLOW_DRAW=off

sketchybar --set "$NAME" icon="$ICON" icon.color="$LEVEL_COLOR" label="${PCT}%" update_freq="$FREQ" \
           --set power_flow drawing="$FLOW_DRAW" icon="${WATTS}W" icon.color="$FLOW_COLOR" \
                 label="${FRAMES[$TICK]}" label.color="$FLOW_COLOR"
