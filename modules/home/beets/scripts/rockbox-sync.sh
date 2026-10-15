#!/usr/bin/env bash
# `rockbox-sync [card]`: mirrors ~/Music/artists onto the player's card root,
# copy-only, so a track removed here stays on the card until deleted by hand.
# Playlists go through rockbox-playlists: generated ones are copied over,
# hand-made ones merged both ways. The player's own settings are backed up
# before ../rockbox/base.cfg and its EQ presets are pushed.
#
# Built by ../rockbox.nix with writeShellApplication, which adds
# `set -euo pipefail` and sets ROCKBOX_CONFIG (the ../rockbox directory).

card="${1:-/media/$USER/H2}"
backups="${XDG_STATE_HOME:-$HOME/.local/state}/rockbox-sync/device"

if [ ! -d "$card/.rockbox" ]; then
  echo "rockbox-sync: no Rockbox install at $card" >&2
  exit 1
fi

# The player rewrites config.cfg on every volume change, so it is backed up
# here rather than in the repo, as a dated snapshot only when something
# differs from the last one. `latest` points at the newest.
snapshot="$(mktemp -d)"
trap 'rm -rf "$snapshot"' EXIT
rsync -rt --include='/*.cfg' --include='/*.txt' --include='/*.config' \
  --include='/eqs/' --include='/eqs/*.cfg' --exclude='*' \
  "$card/.rockbox/" "$snapshot/"
mkdir -p "$backups"
if ! diff -rq "$snapshot" "$backups/latest" >/dev/null 2>&1; then
  dated="$(date +%Y-%m-%dT%H%M%S)"
  mv "$snapshot" "$backups/$dated"
  ln -sfn "$dated" "$backups/latest"
  echo "rockbox-sync: backed up player settings to $backups/$dated"
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

# Store files carry a 1970 mtime, which FAT32 cannot hold, so compare content.
# No --delete: presets saved on the player stay.
rsync -r --checksum "$ROCKBOX_CONFIG/base.cfg" "$card/.rockbox/"
rsync -r --checksum "$ROCKBOX_CONFIG/eqs/" "$card/.rockbox/eqs/"
