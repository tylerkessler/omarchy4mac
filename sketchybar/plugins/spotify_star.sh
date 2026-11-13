#!/usr/bin/env bash
# Click on the bar's star: save the playing song to Your Library, or take it out (tyler-os coach/spotify_library.py).
# Says what happened in a Mac banner only when it did not work, then redraws the pill at once.
OUT="$(python3 "$HOME/Scripts/tyler-os-live/coach/spotify_library.py" toggle 2>&1)" || \
  osascript -e "display notification \"$(printf '%s' "$OUT" | tr '"' "'")\" with title \"Spotify\"" >/dev/null 2>&1
SENDER=spotify_refresh bash "$(dirname "$0")/spotify.sh"
