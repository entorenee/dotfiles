#!/usr/bin/env bash
# `beets-random`: rewrites the random playlist in ~/Music/playlists with two
# hours of tracks, each album artist equally likely, so a prolific artist
# doesn't crowd out the rest. Entries read artists/…, matching the
# smartplaylist ones, which is the form MPD reads; rockbox-playlists
# rewrites them for the card.
#
# Built by ../default.nix with writeShellApplication, which adds
# `set -euo pipefail` and sets RANDOM_PLAYLIST (the file name).

dir="$HOME/Music/playlists"
tmp="$(mktemp -p "$dir")"
trap 'rm -f "$tmp"' EXIT

beet random -e -t 120 -f "\$path" |
  sed "s#^$HOME/Music/artists/#artists/#" >"$tmp"
mv "$tmp" "$dir/$RANDOM_PLAYLIST"
