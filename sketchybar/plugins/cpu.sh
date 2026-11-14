#!/usr/bin/env bash
# CPU + RAM pill (tyler-os #1419). Ticks every 8 s (3 s while its popup is open); popups.py redraws the popup only while it is open.
case "$SENDER" in
  mouse.exited.global) exec "$(dirname "$0")/popup.sh" close cpu ;;
  mouse.*) exit 0 ;;
esac
exec /usr/bin/perl -e 'alarm 10; exec @ARGV' /usr/bin/python3 "$(dirname "$0")/../lib/popups.py" cpu-tick
