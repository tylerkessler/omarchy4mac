#!/usr/bin/env bash
# Battery click: a Ghostty window with `tyler battery watch` (tyler-os #1150): this Mac live, every device's last
# report and age, 24 h sparklines, the battery log. Ctrl-C stops it; any key closes the window.
# A new window in the running Ghostty, never a second Ghostty instance; 5 s cap so a stuck AppleScript can't pile up.
CMD="$HOME/.local/bin/omarchy-tui tyler battery watch"
/usr/bin/perl -e 'alarm 5; exec @ARGV' /usr/bin/osascript \
  -e "tell application \"Ghostty\" to new window with configuration {command:\"$CMD\"}" >/dev/null 2>&1 \
  || open -na Ghostty --args -e "$HOME/.local/bin/omarchy-tui" tyler battery watch
