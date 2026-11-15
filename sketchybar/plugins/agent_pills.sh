#!/usr/bin/env bash
# Agent status (tyler-os #1424, #1440): the agents pill, the load dot and cu_lock. Driven by events; update_freq is only a slow fallback.
# The agents pill is one line: running/queued jobs ("3 running · 8 queued"). Spend and the 5-hour % live in the Weekly Use block (tyler-os #1468).
# NAME picks the item. SENDER is the event: claude_done (STATUS, LABEL), donna_queue, computer_use_lock, system_woke, routine.
#   agent_pills.sh toggle   (agents click_script) opens/closes the budget popup (5-hour and weekly %).
source "$CONFIG_DIR/colors.sh"
[ -f "$CONFIG_DIR/live_vibe.sh" ] && source "$CONFIG_DIR/live_vibe.sh"
MINT="${STATUS_OK:-${MINT:-$GREEN}}"; GOLD="${STATUS_WARN:-${GOLD:-$YELLOW}}"; RED="${STATUS_BAD:-$RED}"   # sunset status tones (#1425)
SB=/opt/homebrew/bin/sketchybar
CACHE="$HOME/.cache/omarchy4mac"; mkdir -p "$CACHE"
FLASH="$CACHE/claude_done"   # "<until epoch> <status> <label>"
POPUP_STATE="$CACHE/popup_open"
STATE_DIR="$HOME/Library/Application Support/computer-use"

# ---- Claude usage (the Claude Code statusline captures that TKOS Live and Claudia's co-pilot read; nothing is guessed) ----
# Prints "<5h pct> <5h resets epoch> <week pct> <week resets epoch> <age s>", or "-" with no capture under 6 h old.
usage() {
  python3 - <<'P'
import glob, json, os, time
now = time.time()
base = os.path.expanduser(os.environ.get("TKOS_CLAUDE_STATUSLINE", "~/.local/state/tyler-os-vault/claude_statusline.json"))
files = [base] + glob.glob(os.path.join(os.path.dirname(base), "claude_statusline", "*.json"))
found = {}
for f in files:
    try:
        mt = os.stat(f).st_mtime
        if now - mt > 6 * 3600:
            continue
        rl = json.load(open(f)).get("rate_limits") or {}
    except Exception:
        continue
    for k in ("five_hour", "seven_day"):
        x = rl.get(k) or {}
        if x.get("used_percentage") is not None and mt > found.get(k, (0, 0, 0))[2]:
            at = float(x.get("resets_at") or 0)
            found[k] = (0.0 if at and at <= now else float(x["used_percentage"]), at, mt)   # window ended = it reset
if "five_hour" not in found:
    print("-"); raise SystemExit
w = found.get("seven_day", (-1, 0, 0))
print(int(found["five_hour"][0]), int(found["five_hour"][1]), int(w[0]), int(w[1]), int(now - found["five_hour"][2]))
P
}
at_time() { date -r "$1" "+${2:-%-I:%M %p}" 2>/dev/null; }
tier() {   # tier VALUE AMBER RED -> colour
  if [ "$1" -ge "$3" ]; then echo "$RED"; elif [ "$1" -ge "$2" ]; then echo "$GOLD"; else echo "$MINT"; fi
}

fill_budget() {   # popup rows: 5-hour, week, source
  local five_r=$1 five_p=$2 wk_r=$3 wk_p=$4 age=$5 fc wc
  fc="$(tier "$five_p" 30 40)"; wc="$(tier "${wk_p:-0}" 40 50)"
  $SB --set agents.r1 drawing=on label="5-hour   ${five_p}%   (amber 30, stop 40)" label.color="$fc" \
      --set agents.r2 drawing=on label="  resets $(at_time "$five_r")" label.color="$FG"
  if [ "${wk_p:-0}" -ge 0 ] 2>/dev/null && [ "$wk_r" != 0 ]; then
    $SB --set agents.r3 drawing=on label="Week     ${wk_p}%   (stop 50)" label.color="$wc" \
        --set agents.r4 drawing=on label="  resets $(at_time "$wk_r" '%a %-I:%M %p')  ·  read $((age / 60)) min ago" label.color="$FG"
  else
    $SB --set agents.r3 drawing=on label="Week     –   (no reading yet)" label.color="$FG" --set agents.r4 drawing=off
  fi
}

close_popup() { $SB --set agents popup.drawing=off; [ "$(cat "$POPUP_STATE" 2>/dev/null)" = agents ] && : > "$POPUP_STATE"; }

# "5h 73%" and its tier colour (amber at 30, red at 40), or nothing without a reading under 6 h old.
BUDGET_TEXT=""; BUDGET_C=""
budget() {
  local out five_p five_r wk_p wk_r age
  out="$(usage)"
  [ "$out" = "-" ] || [ -z "$out" ] && return
  read -r five_p five_r wk_p wk_r age <<<"$out"
  BUDGET_TEXT="5h ${five_p}%"; [ "$five_p" -ge 30 ] && BUDGET_C="$(tier "$five_p" 30 40)"
  [ "$(cat "$POPUP_STATE" 2>/dev/null)" = agents ] && fill_budget "$five_r" "$five_p" "$wk_r" "$wk_p" "$age"
}

# ---- queue: Claude tabs in TKOS that are working + live Donna watchers ("2 running · 1 queued", nothing when idle) ----
queue() {
  local running=0 queued tmux=/opt/homebrew/bin/tmux w
  [ -x "$tmux" ] || tmux="$(command -v tmux)"
  if [ -n "$tmux" ]; then
    # Read-only: a pane counts when its last lines show the working footer ("esc to interrupt") or a spinner ("Puttering… (16m 49s)").
    while read -r w; do
      "$tmux" capture-pane -p -t "$w" 2>/dev/null | tail -12 | grep -Eq 'esc to interrupt|[A-Za-z]+… \(' && running=$((running + 1))
    done < <("$tmux" list-panes -s -t TKOS -F '#{window_id} #{pane_current_command}' 2>/dev/null | awk '$2 == "claude.exe" {print $1}')
  fi
  queued="$(ps -axo command= | grep -oE '\.donna/watchers/[A-Za-z0-9_.-]+\.(sh|py|zsh)' | sort -u | wc -l | tr -d ' ')"
  [ "$running" -gt 0 ] && printf '%s running' "$running"
  [ "$running" -gt 0 ] && [ "$queued" -gt 0 ] && printf ' · '
  [ "$queued" -gt 0 ] && printf '%s queued' "$queued"
}

# ---- the agents pill: queue only ("3 running · 8 queued", or "idle"). Spend and the 5-hour % are not here: the Weekly Use block in the
# bottom scroller already shows them (tyler-os #1468). Click still opens the 5-hour + weekly popup. ----
agents() {
  "$CONFIG_DIR/plugins/agent_status.sh"   # logo motion + TK colour ride this item's update
  local q
  q="$(queue)"
  budget   # only refreshes the popup rows while the popup is open
  $SB --set agents drawing=on icon="󰚩" icon.color="${SUN_2:-$FG}" label="${q:-idle}" label.color="$FG"
}

flash_active() {
  local until status label
  read -r until status label < "$FLASH" 2>/dev/null || return 1
  [ -n "$until" ] && [ "$(date +%s)" -lt "$until" ]
}

# click_script path: agent_pills.sh toggle (budget popup under the agents pill)
if [ "${1:-}" = toggle ]; then
  if [ "$(cat "$POPUP_STATE" 2>/dev/null)" = agents ]; then close_popup; exit 0; fi
  "$(dirname "$0")/popup.sh" close   # whichever other popup is open
  out="$(usage)"
  if [ "$out" = "-" ] || [ -z "$out" ]; then
    $SB --set agents.r1 drawing=on label="No Claude usage reading in the last 6 h" label.color="$FG" --set agents.r2 drawing=off --set agents.r3 drawing=off --set agents.r4 drawing=off
  else
    read -r a b c d e <<<"$out"; fill_budget "$b" "$a" "$d" "$c" "$e"
  fi
  printf agents > "$POPUP_STATE"
  $SB --set agents popup.drawing=on
  exit 0
fi

case "$NAME:$SENDER" in
  agents:mouse.exited.global) close_popup; exit 0 ;;
  agents:mouse.*) exit 0 ;;
  agents:claude_done)
    case "$STATUS" in merged) C="$MINT"; W="merged" ;; failed) C="$RED"; W="failed" ;; stalled) C="$RED"; W="stalled" ;; *) exit 0 ;; esac
    echo "$(($(date +%s) + 8)) $STATUS $LABEL" > "$FLASH"
    $SB --set agents drawing=on icon.color="$C" label="$W${LABEL:+ · $LABEL}"
    # Hold about 8 s, then settle (a newer flash moves the deadline, so only the last one settles).
    ( sleep 8.5; flash_active || NAME=agents SENDER=settle CONFIG_DIR="$CONFIG_DIR" bash "$0" ) >/dev/null 2>&1 </dev/null &
    exit 0 ;;
  agents:settle) agents; exit 0 ;;
  agents:*) flash_active && exit 0; agents; exit 0 ;;
  load:*)
    L="$(/usr/sbin/sysctl -n vm.loadavg | awk '{printf "%d", $2 + 0.5}')"
    $SB --set load label="$L" label.color="$(tier "$L" 40 60)"
    exit 0 ;;
  cu_lock:*)
    if [ -d "$STATE_DIR/held" ] || [ "$(cat "$STATE_DIR/COMPUTER_USE_LOCKED" 2>/dev/null)" = 1 ]; then
      H="$(head -1 "$STATE_DIR/held/holder" 2>/dev/null)"; [ -z "$H" ] && H="user block"
      T="$(stat -f %m "$STATE_DIR/held" 2>/dev/null || stat -f %m "$STATE_DIR/COMPUTER_USE_LOCKED" 2>/dev/null)"
      S=$(( $(date +%s) - ${T:-$(date +%s)} )); [ "$S" -lt 60 ] && D="${S}s" || D="$((S / 60))m"
      $SB --set cu_lock drawing=on label="Mac · $H · $D"
    else
      $SB --set cu_lock drawing=off
    fi
    exit 0 ;;
esac

