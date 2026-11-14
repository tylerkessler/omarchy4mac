#!/usr/bin/env bash
# One popup open at a time for the right group (cpu, music_pop, battery; tyler-os #1419).
#   popup.sh toggle NAME   second click closes it; opening one closes whichever other was open
#   popup.sh close [NAME]  mouse left it (closes only if NAME is the open one; no NAME closes whatever is open)
# The open name lives in a one-line file so the pill scripts know when to refresh their popup (only while it is open).
SB=/opt/homebrew/bin/sketchybar
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$HOME/.cache/omarchy4mac/popup_open"
mkdir -p "$(dirname "$STATE")"
cur="$(cat "$STATE" 2>/dev/null)"

# update_freq while a popup is open / closed (0 = no timer; the music icon never polls)
freq() { case "$1:$2" in cpu:open) echo 3;; cpu:closed) echo 8;; music_pop:open) echo 2;; music_pop:closed) echo 0;; *) echo "";; esac; }
set_freq() { local f; f="$(freq "$1" "$2")"; [ -n "$f" ] && "$SB" --set "$1" update_freq="$f"; }

close_open() {
  [ -z "$cur" ] && return
  "$SB" --set "$cur" popup.drawing=off
  set_freq "$cur" closed
  : > "$STATE"
}

case "$1" in
  toggle)
    name="$2"
    if [ "$cur" = "$name" ]; then close_open; exit 0; fi
    close_open
    /usr/bin/perl -e 'alarm 8; exec @ARGV' /usr/bin/python3 "$DIR/../lib/popups.py" fill "$name"
    printf '%s' "$name" > "$STATE"
    "$SB" --set "$name" popup.drawing=on
    set_freq "$name" open
    ;;
  close)
    if [ -z "$2" ] || [ "$cur" = "$2" ]; then close_open; fi
    ;;
esac
