#!/usr/bin/env bash
# Battery island: [ 34W ··• ] [ 󰂊 85% ]
#   power_flow  watts + a travelling dot. Charging: charger watts, the dot moves right INTO the battery (mint).
#               On battery: what the Mac is drawing, the dot moves left OUT of the battery (orange).
#               Plugged in but holding (full or at the charge limit): charger watts, still dots (dim).
#   battery     level glyph tinted by charge, and the percent.
# One ioreg read per run. It runs every 2 s while power moves (the dot needs the tick) and every 30 s while holding.
# Click: the battery popup (popup.sh); its last row opens a terminal with `tyler battery watch` (every device, last report, 24 h sparklines; tyler-os #1150).
case "$SENDER" in
  mouse.exited.global) exec "$CONFIG_DIR/plugins/popup.sh" close battery ;;
  mouse.*) exit 0 ;;
esac
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
# Sunset bands (tyler-os #1527): charging or >=50 lavender, 30-49 orange, 20-29 amber, <20 coral.
# Below lavender the island breathes: each tick SketchyBar eases the colour (and the island's outline) to the other
# phase, bright or a subtle dim twin, so the beat quickens as the battery worsens: orange a 4 s breath (2 s ticks,
# 2 s ease), amber 2 s, coral a sharper 1 s-tick beat, under 10 % a white flash. Charging is always calm lavender.
# SketchyBar ticks are whole seconds, so coral and under-10 cannot breathe faster than a 2 s cycle; their ease is shorter.
LAV="0xffc8b6ff"; ORG="0xffff8b4b"; AMB="0xffffb52e"; COR="0xffff5a6e"
ORG_D="0xb3ff8b4b"; AMB_D="0xb3ffb52e"; COR_D="0xb3ff5a6e"
NOW_S=$(date +%s); PULSE_FREQ=""; EASE=""
if [ "$STATE" = charging ] || [ "$PCT" -ge 50 ]; then
  LEVEL_COLOR="$LAV"
elif [ "$PCT" -ge 30 ]; then
  PULSE_FREQ=2; EASE=120; LEVEL_COLOR="$ORG"; [ $(( NOW_S / 2 % 2 )) -eq 1 ] && LEVEL_COLOR="$ORG_D"
elif [ "$PCT" -ge 20 ]; then
  PULSE_FREQ=1; EASE=60; LEVEL_COLOR="$AMB"; [ $(( NOW_S % 2 )) -eq 1 ] && LEVEL_COLOR="$AMB_D"
elif [ "$PCT" -ge 10 ]; then
  PULSE_FREQ=1; EASE=30; LEVEL_COLOR="$COR"; [ $(( NOW_S % 2 )) -eq 1 ] && LEVEL_COLOR="$COR_D"
else
  PULSE_FREQ=1; EASE=15; LEVEL_COLOR="$COR"; [ $(( NOW_S % 2 )) -eq 1 ] && LEVEL_COLOR="0xffffffff"
fi

TICK=$(( $(date +%s) / 2 % 3 ))
case "$STATE" in
  charging) FRAMES=("•··" "·•·" "··•"); WATTS="$W_IN"; FLOW_COLOR="$MINT"; ICON="${BOLT[$LEVEL]}"; FREQ=2 ;;
  draining) FRAMES=("··•" "·•·" "•··"); WATTS="$W_OUT"; FLOW_COLOR="$SUN_1"; ICON="${PLAIN[$LEVEL]}"; FREQ=2 ;;
  *)        FRAMES=("···" "···" "···"); WATTS="$W_IN"; FLOW_COLOR="$DIM"; ICON="${BOLT[$LEVEL]}"; FREQ=30 ;;
esac

[ -n "$PULSE_FREQ" ] && FREQ="$PULSE_FREQ"
FLOW_DRAW=on
[ "$WATTS" -le 0 ] && FLOW_DRAW=off

# Colours ease only while the island breathes; otherwise they are set straight (no animation, no extra redraw).
if [ -n "$EASE" ]; then
  sketchybar --animate sin "$EASE" --set "$NAME" icon.color="$LEVEL_COLOR" label.color="$LEVEL_COLOR" \
                                    --set vibe_batt background.border_color="$LEVEL_COLOR"
else   # calm: the outline goes back to the island's gold (sketchybarrc pill_args GRAD_6)
  sketchybar --set "$NAME" icon.color="$LEVEL_COLOR" label.color="$LEVEL_COLOR" \
             --set vibe_batt background.border_color="${GRAD_6:-0xffffca00}"
fi
sketchybar --set "$NAME" icon="$ICON" label="${PCT}%" update_freq="$FREQ" \
           --set power_flow drawing="$FLOW_DRAW" icon="${WATTS}W" icon.color="$FLOW_COLOR" \
                 label="${FRAMES[$TICK]}" label.color="$FLOW_COLOR"
# Popup (tyler-os #1419): redrawn on this tick only while it is open.
[ "$(cat "$HOME/.cache/omarchy4mac/popup_open" 2>/dev/null)" = "battery" ] && \
  /usr/bin/perl -e 'alarm 5; exec @ARGV' /usr/bin/python3 "$CONFIG_DIR/lib/popups.py" fill battery
