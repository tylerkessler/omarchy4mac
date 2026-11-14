#!/usr/bin/env bash
# Keyboard pill: click opens the floating keyboard cheat sheet on the frontmost app's shortcuts (same as alt-shift-/).
# Shared pill look (lib/pill_item.sh), sunset peach accent (tyler-os #1425). Sourced from sketchybarrc; bin/keysheet does the work.
sketchybar --add item keys left \
           --set keys \
                 icon="⌘" icon.font="Hack Nerd Font:Bold:15.0" \
                 label.drawing=off \
                 click_script="$HOME/.local/bin/keysheet" \
                 $(pill_item_args "${GRAD_1:-$ACCENT}")
