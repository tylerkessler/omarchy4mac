#!/usr/bin/env bash
# Agent status for the bar (tyler-os #1418). Reads what TKOS Live's agents grid reads (coach/agents_grid.py, so the logo and the
# agents count agree) and the TK OS favicon tone (coach/favicon.py _favicon_status, the source tmux-pulse uses).
#  - logo: a still yellow-orange sun (SUN_LOGO), never animated (tyler-os #1425).
#  - tk:   coloured by the favicon tone in sunset status colours, repainted only when the tone changes.
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

# TK: the favicon tone in sunset status colours (tyler-os #1425), repainted only on a change. Static: no tween.
case "$TONE" in
  ok) TK="${STATUS_OK:-$FG}" ;; warn) TK="${STATUS_WARN:-$FG}" ;; bad) TK="${STATUS_BAD:-$FG}" ;; *) TK="${GRAD_1:-$FG}" ;;
esac
if [ "$(cat "$DIR/tk_tone" 2>/dev/null)" != "$TONE" ]; then
  sketchybar --set tk icon.color="$TK" && echo "$TONE" >"$DIR/tk_tone"
fi

# Logo: a still yellow-orange sun, whatever the agents do (Tyler, 2026-11-14, tyler-os #1425: "make everything static").
if [ "$(cat "$DIR/logo_state" 2>/dev/null)" != "sun" ]; then
  sketchybar --set logo icon.color="${SUN_LOGO:-$ACCENT}"
  echo sun >"$DIR/logo_state"
fi
