#!/usr/bin/env bash
# Keyboard pill: click opens the floating keyboard cheat sheet on the frontmost app's shortcuts (same as alt-shift-/).
# Shared pill look (lib/pill_item.sh), cyan accent. Sourced from sketchybarrc; bin/keysheet does the work.
sketchybar --add item keys left \
           --set keys \
                 icon="⌨️" \
                 label.drawing=off \
                 click_script="$HOME/.local/bin/keysheet" \
                 $(pill_item_args 0xff63e6e2)
