{
  config,
  lib,
  pkgs,
  ...
}: let
  # Python body for an `inline` field: lowercases `expr`, drops apostrophes,
  # and collapses every run of anything but letters and digits into one
  # hyphen. Letters in any script survive ("beyoncé", "sigur-rós"), and none
  # of them need shell escaping. NFC composes "e" + combining accent into one
  # "é", so the same name is the same bytes on Linux and macOS (Syncthing).
  slug = expr: ''
    import re, unicodedata
    name = unicodedata.normalize("NFC", ${expr})
    name = re.sub(r"['’]", "", name.lower())
    return re.sub(r"[\W_]+", "-", name).strip("-")
  '';

  # `rockbox-scrobble [card]`: submits the player's playback.log to
  # ListenBrainz, then moves it off the card into ~/.local/state. Each line is
  # end-time:elapsed-ms:length-ms:path with no tags, so metadata comes from
  # beets by path. The player's clock has no timezone and runs on local wall
  # time, so its epochs are shifted back to real UTC.
  rockboxScrobble = pkgs.writeShellApplication {
    name = "rockbox-scrobble";
    runtimeInputs = [config.programs.beets.package pkgs.coreutils pkgs.curl pkgs.gnugrep pkgs.jq pkgs.yq-go];
    text = ''
      card="''${1:-/media/$USER/H2}"
      log="$card/.rockbox/playback.log"
      library="$HOME/Music/artists"
      archive="''${XDG_STATE_HOME:-$HOME/.local/state}/rockbox-scrobble"

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

        file="$library/''${path#*/artists/}"
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

      token="$(yq '.listenbrainz.token' "${config.age.secrets.beets-listenbrainz.path}")"
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
    '';
  };

  # `rockbox-playlists <desktop-dir> <card-dir>`: two-way sync of the playlist
  # folders. beets' generated playlists only go to the card. Hand-made ones are
  # merged with diff3 against the result of the last sync, kept in
  # ~/.local/state, so an edit on either side survives and a conflict writes
  # neither side. Tracks the desktop dropped are confirmed first, because a
  # stale Strawberry "Save all" looks exactly like deliberate pruning.
  rockboxPlaylists = pkgs.writeShellApplication {
    name = "rockbox-playlists";
    runtimeInputs = [pkgs.coreutils pkgs.diffutils pkgs.gawk pkgs.gnugrep pkgs.gnused];
    text = ''
      desktop="$1"
      card="$2"
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/rockbox-sync"
      generated=(${lib.concatMapStringsSep " " (p: lib.escapeShellArg p.name) config.programs.beets.settings.smartplaylist.playlists})

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
        rm -f "$state/conflicts/''${1%.m3u8}.conflict.m3u8"
      }

      # Keeps the marked-up $tmp/result for playlist $1 and writes neither side.
      conflict() {
        local kept="$state/conflicts/''${1%.m3u8}.conflict.m3u8"
        changed=1
        cp "$tmp/result" "$kept"
        echo "$1: conflict, neither side written; see $kept"
      }

      for g in "''${generated[@]}"; do
        if [ -f "$desktop/$g" ] && ! cmp -s "$desktop/$g" "$card/$g"; then
          cp "$desktop/$g" "$card/$g"
          changed=1
          echo "$g: updated (generated)"
        fi
      done

      shopt -s nullglob
      declare -A seen=()
      for f in "$desktop"/*.m3u8 "$card"/*.m3u8 "$state/base"/*.m3u8; do
        seen["''${f##*/}"]=1
      done
      for g in "''${generated[@]}"; do
        unset "seen[$g]"
      done
      names=()
      if [ ''${#seen[@]} -gt 0 ]; then
        mapfile -d "" names < <(printf '%s\0' "''${!seen[@]}" | sort -z)
      fi

      for n in "''${names[@]}"; do
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
        if [ ''${#empty[@]} -gt 0 ]; then
          echo "$n: empty, skipped (''${empty[*]})"
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
    '';
  };
in {
  # Music library manager: tags from MusicBrainz, then files tracks into
  # ~/Music by the path templates below. Every path component is kebab-case,
  # e.g. cheap-perfume/2019-burn-it-down/01-put-the-devil-to-bed.flac
  programs.beets = {
    enable = true;

    settings = {
      directory = "~/Music/artists";

      # The ListenBrainz token and username, decrypted by agenix below.
      include = ["listenbrainz.yaml"];

      # Since beets 2.4 the MusicBrainz autotagger is a plugin like any other,
      # so naming a plugin list without it turns tagging off.
      plugins = [
        "musicbrainz"
        "chroma" # AcoustID fingerprinting, for files with no usable tags
        "fetchart"
        "embedart"
        "inline"
        "duplicates"
        "info"
        "smartplaylist"
        "listenbrainz" # `beet lbimport` pulls listen counts into the library
      ];

      import = {
        write = true;
        copy = false;
        move = true;
        log = "~/.config/beets/import.log";
      };

      # The year of first release, not of whichever reissue matched.
      original_date = true;

      # Matches the cover.jpg already sitting in each album folder.
      art_filename = "cover";
      fetchart.auto = true;
      embedart.auto = true;

      # Python bodies the `inline` plugin exposes as $fields in path templates.
      # Slugs only shape file paths; the embedded tags keep the real names.
      # Kebab-case needs no shell escaping, and fzf matches "beyonce" to
      # "beyoncé" by default, so the accents cost nothing at the prompt.
      item_fields = {
        artist_slug = slug "albumartist or artist";
        album_slug = slug "album";
        title_slug = slug "title";
        # "2-" on multi-disc releases only, so single-disc albums stay "01-…".
        disc_prefix = ''
          return f"{disc}-" if disctotal > 1 else ""
        '';
      };

      # First matching query wins; `default` is the fallback.
      paths = {
        "albumtype:single" = "$artist_slug/singles/$title_slug";
        singleton = "$artist_slug/singles/$title_slug";
        comp = "various-artists/%if{$year,$year-}$album_slug/$disc_prefix$track-$title_slug";
        default = "$artist_slug/%if{$year,$year-}$album_slug/$disc_prefix$track-$title_slug";
      };

      ## Plugin configuration
      smartplaylist = {
        auto = true;
        playlist_dir = "~/Music/playlists";
        # Entries read ../artists/…, which resolves both here and on the
        # Rockbox card, since the card mirrors ~/Music.
        relative_to = "~/Music/playlists";
        playlists = [
          {
            name = "Recently Added.m3u8";
            query = "added:-1m..";
          }
          {
            # Negated, so tracks with no recorded listens (no field) match.
            name = "Underplayed.m3u8";
            query = "^listenbrainz_play_count:6..";
          }
        ];
      };
    };
  };

  # YAML holding `listenbrainz: {username, token}`. The listenbrainz plugin
  # reads both at load, so beets refuses to start until this decrypts.
  age.secrets.beets-listenbrainz = {
    file = ../../../secrets/beets-listenbrainz.age;
    path = "${config.xdg.configHome}/beets/listenbrainz.yaml";
    mode = "0400";
  };

  # Daily: pull ListenBrainz plays, then rebuild every playlist. splupdate runs
  # unconditionally because `auto` only rewrites playlists a changed track
  # matches, so a quiet day would never age anything out of Recently Added.
  # Linux only, since Strawberry is the only consumer and it only runs there.
  systemd.user.services.beets-refresh = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Import ListenBrainz plays into beets and rebuild playlists";
      # The token has to be decrypted before the listenbrainz plugin loads.
      After = ["agenix.service"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "beets-refresh" ''
        set -eu
        ${lib.getExe' config.programs.beets.package "beet"} lbimport
        ${lib.getExe' config.programs.beets.package "beet"} splupdate
      '');
    };
  };

  # `rockbox-sync [card]`: mirrors ~/Music/artists onto the player's card root,
  # copy-only, so a track removed here stays on the card until deleted by hand.
  # Playlists go through rockbox-playlists: generated ones are copied over,
  # hand-made ones merged both ways.
  home.packages = lib.mkIf pkgs.stdenv.isLinux [
    rockboxScrobble
    (pkgs.writeShellApplication {
      name = "rockbox-sync";
      runtimeInputs = [config.programs.beets.package pkgs.rsync rockboxScrobble rockboxPlaylists];
      text = ''
        card="''${1:-/media/$USER/H2}"

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
      '';
    })
  ];

  systemd.user.timers.beets-refresh = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Daily ListenBrainz import and playlist rebuild";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };
}
