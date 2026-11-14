#!/usr/bin/env bash
# Agent status, top-right group (tyler-os #1424, #1440). Sourced from sketchybarrc, after the right-group popups.
# Right items lay out right-to-left in add order, so reading the bar left to right: cu_lock, load, then the pills already there.
#   agents   "$18 · 2 running · 5h 73%": spend, queue, Claude 5-hour budget (icon amber at 30, red at 40); click = 5-hour + weekly %.
#            Flashes green/red for 8 s on claude_done (bin/claude-done), recounts on donna_queue (bin/donna-queue)
#   load     dot: green under 40, amber 40-60, red over 60 (1-minute load average)
#   cu_lock  lit while ~/Scripts/computer-use-lock is held; the lock script triggers computer_use_lock
# Events, not fast polls: every item only has a slow fallback timer. One plugin (plugins/agent_pills.sh) drives all three.
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

# Queue and budget live in the agents pill's text now (one pill instead of three, tyler-os #1440); its popup is the budget detail.
sketchybar --set agents \
                 script="$PLUGIN_DIR/agent_pills.sh" \
                 click_script="$PLUGIN_DIR/agent_pills.sh toggle" \
                 popup.align=right \
                 $(popup_args "$MINT") \
           --subscribe agents system_woke claude_done donna_queue mouse.exited.global
popup_rows agents 4

sketchybar --add item cu_lock right \
           --set cu_lock \
                 drawing=off icon="󰌾" label="Mac" \
                 update_freq=30 updates=on \
                 script="$PLUGIN_DIR/agent_pills.sh" \
                 $(pill_item_args "$RED") \
           --subscribe cu_lock computer_use_lock system_woke
