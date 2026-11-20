#!/usr/bin/env bash
# Reporting menu (tyler-os coach/report_menu.py holds the actions and the row list).
#   report_menu.sh setup        build the icon, the 3 big buttons (a horizontal popup) and the list (a second popup below)
#   report_menu.sh toggle|close
#   report_menu.sh act KEY      close the menu, then run the action
# Hover: leaving the icon and both popups closes them after 0.7 s, unless the pointer enters any menu item first, so the
# small gap between the button row and the list never counts as leaving.
SB=/opt/homebrew/bin/sketchybar
PY="${TKOS_REPORT_MENU:-$HOME/Scripts/tyler-os-live/coach/report_menu.py}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ST="$HOME/.cache/omarchy4mac"; mkdir -p "$ST"
now() { /usr/bin/perl -MTime::HiRes=time -e 'printf "%d", time*1000'; }

open_menu() { "$DIR/popup.sh" close; "$SB" --set report popup.drawing=on --set report_list popup.drawing=on; echo 1 >"$ST/report_open"; }
close_menu() { "$SB" --set report popup.drawing=off --set report_list popup.drawing=off; : >"$ST/report_open"; }

case "${1:-$SENDER}" in
  toggle) if [ -s "$ST/report_open" ]; then close_menu; else open_menu; fi ;;
  close) close_menu ;;
  act) close_menu; /usr/bin/python3 "$PY" "$2" >/dev/null 2>&1 & ;;
  mouse.entered) now >"$ST/report_hover" ;;
  mouse.exited.global)
    t="$(now)"; echo "$t" >"$ST/report_left"
    ( sleep 0.7; h="$(cat "$ST/report_hover" 2>/dev/null || echo 0)"; l="$(cat "$ST/report_left")"
      [ "$l" = "$t" ] && [ "${h:-0}" -lt "$t" ] && close_menu ) >/dev/null 2>&1 & ;;
  setup)
    source "$DIR/../colors.sh"
    W=458
    eval "$(/usr/bin/python3 - "$PY" <<'PYEOF'
import json, subprocess, sys, shlex
d = json.loads(subprocess.run(["/usr/bin/python3", sys.argv[1], "list"], capture_output=True, text=True).stdout)
q = shlex.quote
for i, (k, name, glyph, hint) in enumerate(d["buttons"], 1):
    label = name + (f" {hint}" if hint else "")
    print(f"BTN_{i}_KEY={q(k)}; BTN_{i}_LABEL={q(label)}; BTN_{i}_ICON={q(glyph)}")
rows = [("h", "Log", "")] + [("r",) + tuple(r) for r in d["log"]] + [("h", "Diagnose and View", "")] + [("r",) + tuple(r) for r in d["view"]]
print("ROWS=(" + " ".join(q("|".join(r)) for r in rows) + ")")
PYEOF
)"
    "$SB" --add item report right \
          --set report icon="" icon.font="Hack Nerd Font:Bold:15.0" icon.color="$FG" label.drawing=off label.max_chars=40 \
                label.color="$FG" background.drawing=off script="$DIR/report_menu.sh" click_script="$DIR/report_menu.sh toggle" \
                popup.horizontal=on popup.align=right popup.background.color=0x00000000 popup.y_offset=6 \
          --subscribe report mouse.entered mouse.exited.global
    # The list popup hangs off a zero-width anchor added after the icon, which lands at the icon's right edge, so both
    # popups share that edge (align=right).
    "$SB" --add item report_list right \
          --set report_list width=0 icon.drawing=off label.drawing=off background.drawing=off padding_left=0 padding_right=0 \
                popup.align=right popup.background.color="${PLUM:-$BG}" popup.background.corner_radius=12 \
                popup.background.border_width=1 popup.background.border_color="${GRAD_5:-$ACCENT}" popup.y_offset=66 \
          --subscribe report_list mouse.exited.global
    accents=("${GRAD_1:-$ACCENT}" "${GRAD_3:-$ACCENT}" "${GRAD_5:-$ACCENT}")
    for i in 1 2 3; do
      k="BTN_${i}_KEY"; l="BTN_${i}_LABEL"; g="BTN_${i}_ICON"; c="${accents[$((i-1))]}"
      "$SB" --add item "report.b$i" popup.report \
            --set "report.b$i" icon="${!g}" icon.font="Hack Nerd Font:Bold:16.0" icon.color="$c" icon.padding_left=12 \
                  label="${!l}" label.font="Hack Nerd Font:Bold:12.0" label.color="$FG" label.padding_right=10 label.width=112 label.align=center icon.width=26 \
                  width=150 align=center padding_left=2 padding_right=2 background.height=48 background.corner_radius=12 \
                  background.color="${PLUM:-$BG}" background.border_width=2 background.border_color="$c" background.drawing=on \
                  script="$DIR/report_menu.sh" click_script="$DIR/report_menu.sh act ${!k}" \
            --subscribe "report.b$i" mouse.entered
    done
    n=0
    for row in "${ROWS[@]}"; do
      IFS='|' read -r kind key name glyph <<<"$row"; n=$((n+1)); it="report_list.r$n"
      if [ "$kind" = h ]; then
        "$SB" --add item "$it" popup.report_list \
              --set "$it" icon.drawing=off label="$key" label.font="Hack Nerd Font:Bold:11.0" label.color="${GRAD_6:-$FG}" \
                    label.padding_left=12 width=$W background.height=24 background.drawing=off
      else
        "$SB" --add item "$it" popup.report_list \
              --set "$it" icon="$glyph" icon.font="Hack Nerd Font:Bold:13.0" icon.color="${GRAD_4:-$ACCENT}" icon.width=26 \
                    icon.padding_left=14 label="$name" label.font="Hack Nerd Font:Bold:12.0" label.color="$FG" width=$W \
                    background.height=22 background.drawing=off script="$DIR/report_menu.sh" \
                    click_script="$DIR/report_menu.sh act $key" \
              --subscribe "$it" mouse.entered
      fi
    done ;;
esac
