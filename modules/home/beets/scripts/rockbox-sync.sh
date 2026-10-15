#!/usr/bin/env bash
# `rockbox-sync [card]`: mirrors ~/Music/artists onto the player's card root,
# copy-only, so a track removed here stays on the card until deleted by hand.
# Playlists go through rockbox-playlists: generated ones are copied over,
# hand-made ones merged both ways. The player's own settings are copied into
# the repo before ../rockbox/base.cfg and its EQ presets are pushed.
#
# Built by ../rockbox.nix with writeShellApplication, which adds
# `set -euo pipefail` and sets ROCKBOX_CONFIG (the ../rockbox directory) and
# ROCKBOX_BACKUP (../rockbox-device in the live checkout).

card="${1:-/media/$USER/H2}"

if [ ! -d "$card/.rockbox" ]; then
  echo "rockbox-sync: no Rockbox install at $card" >&2
  exit 1
fi

# Backed up into the repo so `git diff` shows what changed on the player,
# volume included. Only files edited on the player are kept; stock ones are
# replaced by firmware updates, and the presets this script pushes are
# already in the repo.
pushed=()
for preset in "$ROCKBOX_CONFIG"/eqs/*.cfg; do
  pushed+=(--exclude="/eqs/${preset##*/}")
done
mkdir -p "$ROCKBOX_BACKUP"
rsync -r --checksum --delete "${pushed[@]}" \
  --include='/shortcuts.txt' --include='/playername.txt' --include='/tagnavi_user.config' \
  --include='/eqs/' --include='/eqs/*.cfg' --exclude='*' \
  "$card/.rockbox/" "$ROCKBOX_BACKUP/"

# Rockbox saves settings to config.cfg.new and swaps it in at the next boot.
# Whichever the player will load next is kept as config.cfg, so the swap
# itself is not a diff.
current="$card/.rockbox/config.cfg"
if [ -f "$current.new" ]; then
  current="$current.new"
fi
cp "$current" "$ROCKBOX_BACKUP/config.cfg"

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
