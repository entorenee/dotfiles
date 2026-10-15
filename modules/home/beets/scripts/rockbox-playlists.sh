#!/usr/bin/env bash
# `rockbox-playlists <desktop-dir> <card-dir>`: two-way sync of the playlist
# folders. beets' generated playlists only go to the card. Hand-made ones are
# merged with diff3 against the result of the last sync, kept in
# ~/.local/state, so an edit on either side survives and a conflict writes
# neither side. Tracks the desktop dropped are confirmed first, because a
# stale Strawberry "Save all" looks exactly like deliberate pruning.
#
# Built by ../rockbox.nix with writeShellApplication, which adds
# `set -euo pipefail` and sets ROCKBOX_GENERATED_PLAYLISTS (beets'
# smartplaylist file names, one per line).

desktop="$1"
card="$2"
state="${XDG_STATE_HOME:-$HOME/.local/state}/rockbox-sync"
mapfile -t generated <<<"$ROCKBOX_GENERATED_PLAYLISTS"

for dir in "$desktop" "$card"; do
  if [ ! -d "$dir" ]; then
    echo "rockbox-playlists: no such directory: $dir" >&2
    exit 1
  fi
done
mkdir -p "$state/base" "$state/conflicts"
tmp="$(mktemp -d)"
trap 'rm -r "$tmp"' EXIT
: >"$tmp/empty"
changed=0

# The device appends absolute, volume-prefixed lines (/<microSD0>/artists/…);
# the desktop only reads ../artists/…. awk restores a final newline.
normalize() {
  sed -e 's/\r$//' -e 's#^/\(<[^>]*>/\)\?artists/#../artists/#' "$1" | awk 1
}

# No entries: only #-comments or blank lines, as Save all writes for an
# empty tab.
is_empty() {
  ! grep -qv '^\(#.*\)\?$' "$1"
}

# Merges desktop $1 and card $3 against base $2 into $tmp/result, and
# prints who won: desktop, device, merged or conflict.
merge() {
  if cmp -s "$1" "$2"; then
    cp "$3" "$tmp/result"
    echo device
  elif cmp -s "$3" "$2"; then
    cp "$1" "$tmp/result"
    echo desktop
  else
    local rc=0
    diff3 -m -L desktop -L base -L device "$1" "$2" "$3" >"$tmp/result" || rc=$?
    [ "$rc" -le 1 ] || exit 2
    # A block with an empty base is both sides inserting at the same
    # spot, usually both appending: keep the desktop's lines, then the
    # device's. Only blocks that change a base line stay marked up.
    awk '
      /^<<<<<<< desktop$/ { s = "d"; dl = ""; bl = ""; cl = ""; nb = 0; next }
      s == "d" && /^\|\|\|\|\|\|\| base$/ { s = "b"; next }
      s == "b" && /^=======$/ { s = "c"; next }
      s == "c" && /^>>>>>>> device$/ {
        if (nb == 0) printf "%s%s", dl, cl
        else printf "<<<<<<< desktop\n%s||||||| base\n%s=======\n%s>>>>>>> device\n", dl, bl, cl
        s = ""; next
      }
      s == "d" { dl = dl $0 "\n"; next }
      s == "b" { bl = bl $0 "\n"; nb++; next }
      s == "c" { cl = cl $0 "\n"; next }
      { print }' "$tmp/result" >"$tmp/resolved"
    mv "$tmp/resolved" "$tmp/result"
    if grep -q '^<<<<<<< desktop$' "$tmp/result"; then
      echo conflict
    else
      echo merged
    fi
  fi
}

# Desktop $1 rebuilt against base $2 into $tmp/unremoved: its additions
# and moves stay, and each base line it dropped returns to where it was.
unremove() {
  local rc=0
  diff --old-line-format='-%L' --new-line-format='+%L' --unchanged-line-format=' %L' \
    "$2" "$1" >"$tmp/marked" || rc=$?
  [ "$rc" -le 1 ] || exit 2
  awk -v desk="$1" '
    BEGIN { while ((getline l < desk) > 0) d[l] }
    /^-/ && (substr($0, 2) in d) { next }
    { print substr($0, 2) }' "$tmp/marked" >"$tmp/unremoved"
}

# Entries of $1 that appear nowhere in $2, so a moved track is neither.
missing() {
  awk -v ref="$2" '
    BEGIN { while ((getline l < ref) > 0) r[l] }
    !/^#/ && $0 != "" && !($0 in r)' "$1"
}

# Prints "<name $1>: <how $3> (+added -removed)" for $tmp/result against
# $2, then each removed track.
report() {
  changed=1
  missing "$tmp/result" "$2" >"$tmp/added"
  missing "$2" "$tmp/result" >"$tmp/removed"
  printf '%s: %s (+%s -%s)\n' "$1" "$3" "$(wc -l <"$tmp/added")" "$(wc -l <"$tmp/removed")"
  sed 's#^\(\.\./artists/\)\?#  removed: #' "$tmp/removed"
}

# Writes $tmp/result to both sides and to base for playlist $1.
apply() {
  cmp -s "$tmp/result" "$desktop/$1" || cp "$tmp/result" "$desktop/$1"
  cmp -s "$tmp/result" "$card/$1" || cp "$tmp/result" "$card/$1"
  cp "$tmp/result" "$state/base/$1"
  rm -f "$state/conflicts/${1%.m3u8}.conflict.m3u8"
}

# Keeps the marked-up $tmp/result for playlist $1 and writes neither side.
conflict() {
  local kept="$state/conflicts/${1%.m3u8}.conflict.m3u8"
  changed=1
  cp "$tmp/result" "$kept"
  echo "$1: conflict, neither side written; see $kept"
}

for g in "${generated[@]}"; do
  if [ -f "$desktop/$g" ] && ! cmp -s "$desktop/$g" "$card/$g"; then
    cp "$desktop/$g" "$card/$g"
    changed=1
    echo "$g: updated (generated)"
  fi
done

shopt -s nullglob
declare -A seen=()
for f in "$desktop"/*.m3u8 "$card"/*.m3u8 "$state/base"/*.m3u8; do
  seen["${f##*/}"]=1
done
for g in "${generated[@]}"; do
  unset "seen[$g]"
done
names=()
if [ ${#seen[@]} -gt 0 ]; then
  mapfile -d "" names < <(printf '%s\0' "${!seen[@]}" | sort -z)
fi

for n in "${names[@]}"; do
  d="$desktop/$n"
  c="$tmp/card"
  b="$state/base/$n"
  rm -f "$c"
  if [ -f "$card/$n" ]; then
    normalize "$card/$n" >"$c"
  fi

  empty=()
  if [ -f "$d" ] && is_empty "$d"; then empty+=(desktop); fi
  if [ -f "$c" ] && is_empty "$c"; then empty+=(card); fi
  if [ ${#empty[@]} -gt 0 ]; then
    echo "$n: empty, skipped (${empty[*]})"
    continue
  fi

  if [ -f "$d" ] && [ -f "$c" ] && [ -f "$b" ]; then
    if cmp -s "$d" "$c"; then
      cp "$c" "$tmp/result"
      apply "$n"
      continue
    fi
    how="$(merge "$d" "$b" "$c")"
    if [ "$how" != device ]; then
      # Base entries the desktop dropped and the merge didn't keep. A
      # conflict has no result, so there it's the ones the device still
      # has: a stale save next to a fresh device append conflicts.
      missing "$b" "$d" >"$tmp/dropped"
      if [ "$how" = conflict ]; then
        missing "$tmp/dropped" "$c" >"$tmp/kept"
      else
        cp "$tmp/result" "$tmp/kept"
      fi
      missing "$tmp/dropped" "$tmp/kept" >"$tmp/gone"
      if [ -s "$tmp/gone" ]; then
        echo "$n: the desktop copy drops tracks the device still has:"
        sed 's#^\.\./artists/#  #' "$tmp/gone"
        printf 'Remove them on both sides? [y/N] '
        answer=""
        read -r answer || true
        if [[ "$answer" != [yY]* ]]; then
          unremove "$d" "$b"
          how="$(merge "$tmp/unremoved" "$b" "$c")"
          [ "$how" = conflict ] || how="kept"
        fi
      fi
    fi
    case $how in
    conflict)
      conflict "$n"
      continue
      ;;
    kept) how="merged, removals kept" ;;
    merged) ;;
    *) how="from $how" ;;
    esac
    report "$n" "$b" "$how"
    apply "$n"
  elif [ -f "$d" ] && [ -f "$c" ]; then
    # No base yet: a line-prefix is the other side appending to it.
    if cmp -s "$d" "$c"; then
      cp "$c" "$tmp/result"
      apply "$n"
    elif cmp -s -n "$(wc -c <"$d")" "$d" "$c"; then
      cp "$c" "$tmp/result"
      report "$n" "$d" "from device"
      apply "$n"
    elif cmp -s -n "$(wc -c <"$c")" "$c" "$d"; then
      cp "$d" "$tmp/result"
      report "$n" "$c" "from desktop"
      apply "$n"
    else
      rc=0
      diff3 -m -L desktop -L base -L device "$d" "$tmp/empty" "$c" >"$tmp/result" || rc=$?
      [ "$rc" -le 1 ] || exit 2
      conflict "$n"
    fi
  elif [ -f "$d" ] || [ -f "$c" ]; then
    if [ -f "$d" ]; then
      have="$d" side=desktop other=device
    else
      have="$c" side=device other=desktop
    fi
    if [ ! -f "$b" ]; then
      cp "$have" "$tmp/result"
      report "$n" "$tmp/empty" "new from $side"
      apply "$n"
    elif cmp -s "$have" "$b"; then
      # Unchanged since the last sync, so the deletion stands.
      if [ "$side" = desktop ]; then rm "$d"; else rm "$card/$n"; fi
      rm "$b"
      changed=1
      echo "$n: deleted (on $other)"
    else
      cp "$have" "$tmp/result"
      report "$n" "$b" "restored on $other (changed on $side since last sync)"
      apply "$n"
    fi
  elif [ -f "$b" ]; then
    rm "$b"
  fi
done

if [ "$changed" = 0 ]; then
  echo "rockbox-playlists: nothing changed"
fi
