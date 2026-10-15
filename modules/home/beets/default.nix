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

        file="$library/''${path#*/music/}"
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
        playlists = [
          {
            name = "recently-added.m3u";
            query = "added:-1m..";
          }
          {
            # Negated, so tracks with no recorded listens (no field) match.
            name = "underplayed.m3u";
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
  # matches, so a quiet day would never age anything out of recently-added.
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

  # `rockbox-sync [card]`: copies the library to the player's card at /music
  # and writes the smart playlists there with card-relative paths. Copy-only,
  # so a track removed from beets stays on the card until deleted by hand.
  # The playlists are named .m3u8 above because Rockbox decodes .m3u in a
  # legacy codepage and .m3u8 as UTF-8, and slugs keep accented letters.
  # beets writes the raw path bytes, so both extensions hold the same UTF-8 data.
  # Listens are scrobbled first; a failed
  # upload leaves the log on the card for next time rather than blocking the copy.
  home.packages = lib.mkIf pkgs.stdenv.isLinux [
    rockboxScrobble
    (pkgs.writeShellApplication {
      name = "rockbox-sync";
      runtimeInputs = [config.programs.beets.package pkgs.rsync rockboxScrobble];
      text = ''
        card="''${1:-/media/$USER/H2}"
        library="$HOME/Music/artists"

        if [ ! -d "$card/.rockbox" ]; then
          echo "rockbox-sync: no Rockbox install at $card" >&2
          exit 1
        fi

        rockbox-scrobble "$card" ||
          echo "rockbox-sync: scrobble failed; playback.log kept on the card" >&2

        # FAT32 keeps no owners or modes, and stores mtimes to 2 seconds.
        rsync -rt --modify-window=1 --info=progress2 "$library/" "$card/music/"

        beet splupdate \
          --playlist-dir "$card/playlists" \
          --relative-to "$library" \
          --prefix /music/
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
