#!/usr/bin/env bash
# Agent status pills (tyler-os #1424): queue, budget, load, cu_lock. Driven by events; each item's update_freq is only a slow fallback.
# NAME picks the item. SENDER is the event: claude_done (STATUS, LABEL), donna_queue, computer_use_lock, system_woke, routine.
#   agent_pills.sh toggle   (budget click_script) opens/closes the budget popup (weekly %).
source "$CONFIG_DIR/colors.sh"
[ -f "$CONFIG_DIR/live_vibe.sh" ] && source "$CONFIG_DIR/live_vibe.sh"
MINT="${MINT:-$GREEN}"; GOLD="${GOLD:-$YELLOW}"
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
  $SB --set budget.r1 drawing=on label="5-hour   ${five_p}%   (amber 30, stop 40)" label.color="$fc" \
      --set budget.r2 drawing=on label="  resets $(at_time "$five_r")" label.color="$FG"
  if [ "${wk_p:-0}" -ge 0 ] 2>/dev/null && [ "$wk_r" != 0 ]; then
    $SB --set budget.r3 drawing=on label="Week     ${wk_p}%   (stop 50)" label.color="$wc" \
        --set budget.r4 drawing=on label="  resets $(at_time "$wk_r" '%a %-I:%M %p')  ·  read $((age / 60)) min ago" label.color="$FG"
  else
    $SB --set budget.r3 drawing=on label="Week     –   (no reading yet)" label.color="$FG" --set budget.r4 drawing=off
  fi
}

close_popup() { $SB --set budget popup.drawing=off; [ "$(cat "$POPUP_STATE" 2>/dev/null)" = budget ] && : > "$POPUP_STATE"; }

budget() {
  local out five_p five_r wk_p wk_r age c
  out="$(usage)"
  if [ "$out" = "-" ] || [ -z "$out" ]; then
    $SB --set budget label="5h –" icon.color=0xffffffff $(pill_args_border "$MINT")
    return
  fi
  read -r five_p five_r wk_p wk_r age <<<"$out"
  c="$(tier "$five_p" 30 40)"
  $SB --set budget label="5h ${five_p}%" $(pill_args_border "$c")
  [ "$(cat "$POPUP_STATE" 2>/dev/null)" = budget ] && fill_budget "$five_r" "$five_p" "$wk_r" "$wk_p" "$age"
}
pill_args_border() { printf 'background.border_color=%s' "$1"; }

# ---- queue: Claude tabs in TKOS that are working + live Donna watchers ----
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
  local text
  if [ "$running" -eq 0 ] && [ "$queued" -eq 0 ]; then text="idle"; else text="$running running · $queued queued"; fi
  $SB --set queue label="$text"
}

flash_active() {
  local until status label
  read -r until status label < "$FLASH" 2>/dev/null || return 1
  [ -n "$until" ] && [ "$(date +%s)" -lt "$until" ]
}

settle() {   # back to the quiet look, then recount
  $SB --set queue background.border_color="${SUN_3:-$ACCENT}" background.border_width=2
  queue
}

# click_script path: agent_pills.sh toggle (budget popup)
if [ "${1:-}" = toggle ]; then
  if [ "$(cat "$POPUP_STATE" 2>/dev/null)" = budget ]; then close_popup; exit 0; fi
  "$(dirname "$0")/popup.sh" close   # whichever other popup is open
  out="$(usage)"
  if [ "$out" = "-" ] || [ -z "$out" ]; then
    $SB --set budget.r1 drawing=on label="No Claude usage reading in the last 6 h" label.color="$FG" --set budget.r2 drawing=off --set budget.r3 drawing=off --set budget.r4 drawing=off
  else
    read -r a b c d e <<<"$out"; fill_budget "$b" "$a" "$d" "$c" "$e"
  fi
  printf budget > "$POPUP_STATE"
  $SB --set budget popup.drawing=on
fi

case "$NAME:$SENDER" in
  budget:mouse.exited.global) close_popup; exit 0 ;;
  budget:mouse.*) exit 0 ;;
  queue:claude_done)
    case "$STATUS" in merged) C="$MINT"; W="merged" ;; failed) C="$RED"; W="failed" ;; stalled) C="$RED"; W="stalled" ;; *) exit 0 ;; esac
    echo "$(($(date +%s) + 8)) $STATUS $LABEL" > "$FLASH"
    $SB --set queue background.border_color="$C" label="$W${LABEL:+ · $LABEL}"
    # Hold about 8 s, then settle (a newer flash moves the deadline, so only the last one settles).
    ( sleep 8.5; flash_active || NAME=queue SENDER=settle CONFIG_DIR="$CONFIG_DIR" bash "$0" ) >/dev/null 2>&1 </dev/null &
    exit 0 ;;
  queue:settle) settle; exit 0 ;;
  queue:*) flash_active && exit 0; queue; exit 0 ;;
  budget:*) budget; exit 0 ;;
  load:*)
    L="$(/usr/sbin/sysctl -n vm.loadavg | awk '{printf "%d", $2 + 0.5}')"
    $SB --set load icon.color="$(tier "$L" 40 60)"
    exit 0 ;;
  cu_lock:*)
    if [ -d "$STATE_DIR/held" ] || [ "$(cat "$STATE_DIR/COMPUTER_USE_LOCKED" 2>/dev/null)" = 1 ]; then
      H="$(head -1 "$STATE_DIR/held/holder" 2>/dev/null)"; [ -z "$H" ] && H="user block"
      $SB --set cu_lock drawing=on label="Mac · $H"
    else
      $SB --set cu_lock drawing=off
    fi
    exit 0 ;;
esac

