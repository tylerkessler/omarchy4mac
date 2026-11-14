#!/usr/bin/env bash
# Music popup trigger (tyler-os #1419): no timer while closed; every 2 s while open it redraws the progress bar
# (the Web API is asked at most once per 8 s, see lib/popups.py).
case "$SENDER" in
  mouse.exited.global) exec "$(dirname "$0")/popup.sh" close music_pop ;;
  mouse.*) exit 0 ;;
esac
[ "$(cat "$HOME/.cache/omarchy4mac/popup_open" 2>/dev/null)" = "music_pop" ] || exit 0
exec /usr/bin/perl -e 'alarm 8; exec @ARGV' /usr/bin/python3 "$(dirname "$0")/../lib/popups.py" tick-music
