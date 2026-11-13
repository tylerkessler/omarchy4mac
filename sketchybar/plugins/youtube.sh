#!/usr/bin/env bash
# YouTube pill: shown while a YouTube video is open in Brave (tyler-os #1381). Cheap and event-driven: a front-app or wake event,
# plus a 15 s backstop, reads Brave's window titles from AeroSpace (one list-windows, no osascript, 1 s limit).
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/lib/pill_item.sh"

pgrep -x "Brave Browser" >/dev/null 2>&1 || { sketchybar --set "$NAME" drawing=off; exit 0; }
TITLE="$(/usr/bin/perl -e 'alarm 1; exec @ARGV' /opt/homebrew/bin/aerospace list-windows --all --format '%{app-name}|%{window-title}' 2>/dev/null \
  | python3 "$CONFIG_DIR/lib/extras.py" youtube)"
if [ -n "$TITLE" ]; then pill_show "$NAME" "$TITLE"; else sketchybar --set "$NAME" drawing=off; fi
