#!/usr/bin/env bash
# Agent status pills, top-right group (tyler-os #1424). Sourced from sketchybarrc, after the right-group popups.
# Right items lay out right-to-left in add order, so reading the bar left to right: cu_lock, queue, budget, load, then the pills already there.
#   queue    "2 running · 3 queued"; flashes green/red for 8 s on claude_done (bin/claude-done), recounts on donna_queue (bin/donna-queue)
#   budget   Claude 5-hour usage %, amber at 30, red at 40; click = weekly % (stop 50)
#   load     dot: green under 40, amber 40-60, red over 60 (1-minute load average)
#   cu_lock  lit while ~/Scripts/computer-use-lock is held; the lock script triggers computer_use_lock
# Events, not fast polls: every item only has a slow fallback timer. One plugin (plugins/agent_pills.sh) drives all four.
# The existing computer-use banner (tyler-os coach/cu_bar.py) is a separate full-width banner; cu_lock is only the small "held" light.
MINT="${MINT:-$GREEN}"; GOLD="${GOLD:-$YELLOW}"
sketchybar --add event claude_done \
           --add event donna_queue \
           --add event computer_use_lock

sketchybar --add item load right \
           --set load \
                 icon="●" icon.font="Hack Nerd Font:Bold:14.0" icon.color="$MINT" \
                 label.drawing=off background.drawing=off \
                 padding_left=6 padding_right=0 \
                 update_freq=60 updates=on \
                 script="$PLUGIN_DIR/agent_pills.sh" \
           --subscribe load system_woke

sketchybar --add item budget right \
           --set budget \
                 icon="󰔟" label="5h –" \
                 update_freq=60 updates=on \
                 script="$PLUGIN_DIR/agent_pills.sh" \
                 click_script="$PLUGIN_DIR/agent_pills.sh toggle" \
                 popup.align=right \
                 $(popup_args "$MINT") \
                 $(pill_item_args "$MINT") \
           --subscribe budget system_woke claude_done mouse.exited.global
popup_rows budget 4

sketchybar --add item queue right \
           --set queue \
                 icon="󰚩" label="idle" \
                 update_freq=60 updates=on \
                 script="$PLUGIN_DIR/agent_pills.sh" \
                 $(pill_item_args "${SUN_3:-$ACCENT}") \
           --subscribe queue donna_queue claude_done system_woke

sketchybar --add item cu_lock right \
           --set cu_lock \
                 drawing=off icon="󰌾" label="Mac" \
                 update_freq=30 updates=on \
                 script="$PLUGIN_DIR/agent_pills.sh" \
                 $(pill_item_args "$RED") \
           --subscribe cu_lock computer_use_lock system_woke
