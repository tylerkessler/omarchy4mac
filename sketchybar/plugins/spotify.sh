#!/usr/bin/env bash
# Spotify pill. Always shown; the state comes from the Spotify Web API (works for the phone and any other device, the Mac app
# can be closed). No osascript, ever: an old 5 s osascript poll piled up 100+ stuck processes. The API answer is cached and
# rate limited in tyler-os coach/spotify_library.py, so the 5 s tick below usually costs no network call.
#   update_freq=5   the tick          spotify_change / media_change   the Mac app's track-change event (asks fresh)
# Layout and widths live in spotify_view.py (tests: tests/test_pills.py).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$SENDER" in
  spotify_change|media_change|spotify_refresh) exec /usr/bin/python3 -I "$DIR/spotify_view.py" --fresh ;;
  *) exec /usr/bin/python3 -I "$DIR/spotify_view.py" ;;
esac
