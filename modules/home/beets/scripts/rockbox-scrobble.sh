#!/usr/bin/env bash
# `rockbox-scrobble [card]`: submits the player's playback.log to
# ListenBrainz, then moves it off the card into ~/.local/state. Each line is
# end-time:elapsed-ms:length-ms:path with no tags, so metadata comes from
# beets by path. The player's clock has no timezone and runs on local wall
# time, so its epochs are shifted back to real UTC.
#
# Built by ../rockbox.nix with writeShellApplication, which adds
# `set -euo pipefail` and sets LISTENBRAINZ_SECRET (the agenix-decrypted
# YAML holding the token).

card="${1:-/media/$USER/H2}"
log="$card/.rockbox/playback.log"
library="$HOME/Music/artists"
archive="${XDG_STATE_HOME:-$HOME/.local/state}/rockbox-scrobble"

if ! grep -qv '^#' "$log" 2>/dev/null; then
  echo "rockbox-scrobble: no listens in $log"
  exit 0
fi

listens="$(mktemp)"
trap 'rm -f "$listens"' EXIT

while IFS=: read -r ended elapsed length path; do
  case "$ended" in "#"* | "") continue ;; esac
  # ListenBrainz's rule: half the track, or four minutes.
  if [ $((elapsed * 2)) -lt "$length" ] && [ "$elapsed" -lt 240000 ]; then
    continue
  fi

  file="$library/${path#*/artists/}"
  meta="$(beet ls -f $'$artist\t$title\t$album\t$mb_trackid\t$mb_albumid\t$mb_artistid\t$track' "path:$file")"
  if [ -z "$meta" ]; then
    echo "rockbox-scrobble: not in beets, skipped: $file" >&2
    continue
  fi

  wall="$(date -u -d "@$ended" '+%F %T')"
  started=$(($(date -d "$wall" +%s) - elapsed / 1000))

  jq -nc --arg meta "$meta" --argjson at "$started" --argjson len "$length" '
    ($meta | split("\t")) as [$artist, $title, $album, $recording, $release, $artistid, $track]
    | {listened_at: $at, track_metadata: {
        artist_name: $artist, track_name: $title, release_name: $album,
        additional_info: ({
          media_player: "Rockbox", submission_client: "rockbox-scrobble",
          duration_ms: $len, tracknumber: $track,
          recording_mbid: $recording, release_mbid: $release,
          artist_mbids: [$artistid | select(. != "")]
        } | with_entries(select(.value != "" and .value != [])))
      }}' >>"$listens"
done <"$log"

token="$(yq '.listenbrainz.token' "$LISTENBRAINZ_SECRET")"
# ListenBrainz caps a submission at 1000 listens.
jq -sc 'range(0; length; 1000) as $i | {listen_type: "import", payload: .[$i:$i + 1000]}' "$listens" |
  while read -r batch; do
    curl -fsS -o /dev/null \
      -H @<(printf 'Authorization: Token %s\n' "$token") \
      -H 'Content-Type: application/json' \
      --data-binary "$batch" \
      https://api.listenbrainz.org/1/submit-listens
  done

echo "rockbox-scrobble: submitted $(wc -l <"$listens") listens"
mkdir -p "$archive"
mv "$log" "$archive/playback-$(date +%Y%m%d-%H%M%S).log"
