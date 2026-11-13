#!/usr/bin/env bash
# Click on the Spotify pill: `spotify_click.sh playpause|next`, through the Web API (no Mac app, no osascript).
# A Mac banner only when Spotify refused (not logged in for playback, free account, no device), then the pill redraws at once.
OUT="$(python3 "$HOME/Scripts/tyler-os-live/coach/spotify_library.py" "${1:-playpause}" 2>&1)" || \
  osascript -e "display notification \"$(printf '%s' "$OUT" | tr '"' "'")\" with title \"Spotify\"" >/dev/null 2>&1
SENDER=spotify_refresh bash "$(dirname "$0")/spotify.sh"
