#!/usr/bin/env bash
# Today's Claude Code spend in whole dollars, from the local session logs (ccusage reads ~/.claude/projects); empty on failure.
# Read by plugins/agent_pills.sh, which folds it into the agents pill with the queue and the 5-hour budget (tyler-os #1440).
source "$CONFIG_DIR/plugins/cache.sh"

# ccusage is a heavy node run: one copy at a time, reused for 10 minutes.
spend() {
  PATH="$HOME/.bun/bin:$PATH" bunx ccusage daily --json --since "$(date +%Y%m%d)" 2>/dev/null \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(round(sum(x.get("totalCost",0) for x in d.get("daily",[]))))'
}
cached agents 600 spend
