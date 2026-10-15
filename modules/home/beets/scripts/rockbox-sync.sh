#!/usr/bin/env bash
# `rockbox-sync [card]`: mirrors ~/Music/artists onto the player's card root,
# copy-only, so a track removed here stays on the card until deleted by hand.
# Playlists go through rockbox-playlists: generated ones are copied over,
# hand-made ones merged both ways.
#
# Built by ../rockbox.nix with writeShellApplication, which adds
# `set -euo pipefail`.

card="${1:-/media/$USER/H2}"

if [ ! -d "$card/.rockbox" ]; then
  echo "rockbox-sync: no Rockbox install at $card" >&2
  exit 1
fi

rockbox-scrobble "$card" ||
  echo "rockbox-sync: scrobble failed; playback.log kept on the card" >&2

# The daily refresh may be a day stale; regenerate before copying.
beet splupdate

# No trailing slash: the directory lands by name at the card root.
# FAT32 keeps no owners or modes, and stores mtimes to 2 seconds.
rsync -rt --modify-window=1 --info=progress2 "$HOME/Music/artists" "$card/"

mkdir -p "$card/playlists"
rockbox-playlists "$HOME/Music/playlists" "$card/playlists"
