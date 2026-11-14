#!/usr/bin/env bash
# Agent status, top-right group (tyler-os #1424, #1440). Sourced from sketchybarrc, after the right-group popups.
# Right items lay out right-to-left in add order, so reading the bar left to right: cu_lock, load (the CPU pill's first segment), CPU...
#   agents   "$18 · 2 running · 5h 73%": spend, queue, Claude 5-hour budget (icon amber at 30, red at 40); click = 5-hour + weekly %.
#            Flashes green/red for 8 s on claude_done (bin/claude-done), recounts on donna_queue (bin/donna-queue)
#   load     "LOAD 33" inside the CPU pill (no lone dot, tyler-os #1425): the number is calm under 40, amber 40-60, coral over 60
#   cu_lock  the bar's one computer-use pill, "Mac · Donna · 3m", lit only while ~/Scripts/computer-use-lock is held;
#            the lock script triggers computer_use_lock on acquire and release, so it clears at once (10 s backstop)
# Events, not fast polls: every item only has a slow fallback timer. One plugin (plugins/agent_pills.sh) drives all three.
# The old tyler cu banner (coach/cu_bar.py) is off unless TKOS_CU_BANNER=1 (sketchybarrc). Every colour is a sunset tone (#1425).
MINT="${STATUS_OK:-${MINT:-$GREEN}}"; GOLD="${STATUS_WARN:-${GOLD:-$YELLOW}}"
sketchybar --add event claude_done \
           --add event donna_queue \
           --add event computer_use_lock

sketchybar --add item load right \
           --set load \
                 icon="LOAD" icon.font="Hack Nerd Font:Bold:13.0" icon.color=0xffffffff \
                 icon.padding_left=12 icon.padding_right=5 \
                 label="--" label.color="$MINT" label.padding_left=0 label.padding_right=10 \
                 background.drawing=off padding_left=0 padding_right=0 \
                 update_freq=60 updates=on \
                 script="$PLUGIN_DIR/agent_pills.sh" \
           --subscribe load system_woke

# Queue and budget live in the agents pill's text now (one pill instead of three, tyler-os #1440); its popup is the budget detail.
sketchybar --set agents \
                 script="$PLUGIN_DIR/agent_pills.sh" \
                 click_script="$PLUGIN_DIR/agent_pills.sh toggle" \
                 popup.align=right \
                 $(popup_args "${GRAD_6:-$MINT}") \
           --subscribe agents system_woke claude_done donna_queue mouse.exited.global
popup_rows agents 4

sketchybar --add item cu_lock right \
           --set cu_lock \
                 drawing=off icon="󰌾" label="Mac" \
                 update_freq=10 updates=on \
                 script="$PLUGIN_DIR/agent_pills.sh" \
                 $(pill_item_args "${GRAD_5:-$RED}") \
                 icon.padding_left=12 icon.padding_right=6 label.padding_left=0 label.padding_right=12 padding_right=8 \
           --subscribe cu_lock computer_use_lock system_woke
