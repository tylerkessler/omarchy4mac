#!/usr/bin/env bash
# Agent status for the bar (tyler-os #1418). Reads what TKOS Live's agents grid reads (coach/agents_grid.py, so the logo and the
# agents count agree) and the TK OS favicon tone (coach/favicon.py _favicon_status, the source tmux-pulse uses).
#  - logo: no agent working = still violet; working = steps through the sunset with one gentle pulse (about 2 s) per tick.
#    A Claude session idle at its prompt, waiting on a permission or a question, is not working.
#  - tk:   coloured by the favicon tone, repainted only when the tone changes.
# Runs from the agents item's 30 s update. The python read is cached for 25 s. No loop, no glow, no shadow.
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/cache.sh"

state() {
  python3 - <<'P'
import os, sys
sys.path.insert(0, os.path.expanduser(os.environ.get("TKOS_COACH", "~/Scripts/tyler-os-live/coach")))
w = 0
try:
    import agents_grid as g
    w = sum(1 for c in g.agent_cards() if c.get("status") == "working" and not g.need_of(c))
except Exception:
    pass
try:
    import favicon
    tone = favicon._favicon_status()[0]
except Exception:
    tone = "neutral"
print(w, tone)
P
}
read -r WORKING TONE <<<"$(cached agent_state 25 state)"
WORKING="${WORKING:-0}"; TONE="${TONE:-neutral}"
DIR="$HOME/.cache/sketchybar"; mkdir -p "$DIR"

# TK: favicon fill colours, repainted only on a change.
case "$TONE" in
  ok) TK=0xff3dffa8 ;; warn) TK=0xffffc72c ;; bad) TK=0xffff4d6d ;; *) TK=0xff5b9dff ;;
esac
if [ "$(cat "$DIR/tk_tone" 2>/dev/null)" != "$TONE" ]; then
  sketchybar --animate sin 30 --set tk icon.color="$TK" && echo "$TONE" >"$DIR/tk_tone"
fi

# Logo.
CALM="${SUN_4:-$ACCENT}"
if [ "$WORKING" -gt 0 ] 2>/dev/null && [ -n "$SUN_1" ]; then
  STOPS=("$SUN_1" "$SUN_2" "$SUN_3" "$SUN_4" "$SUN_3" "$SUN_2")
  N=$(( $(cat "$DIR/logo_step" 2>/dev/null || echo 0) + 1 ))
  echo "$N" >"$DIR/logo_step"
  C="${STOPS[$((N % ${#STOPS[@]}))]}"
  sketchybar --animate sin 45 --set logo icon.color="$C"
  sleep 0.8
  sketchybar --animate sin 45 --set logo icon.color="0x8c${C:4}"   # the pulse: fade to 55%, then back up
  sleep 0.8
  sketchybar --animate sin 45 --set logo icon.color="$C"
  echo working >"$DIR/logo_state"
elif [ "$(cat "$DIR/logo_state" 2>/dev/null)" != "still" ]; then
  sketchybar --animate sin 60 --set logo icon.color="$CALM"
  echo still >"$DIR/logo_state"
fi
