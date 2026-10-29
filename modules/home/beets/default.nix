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

  # Written by beets-random rather than smartplaylist, so rockbox.nix is
  # told its name to copy it to the card instead of merging it.
  randomPlaylist = "Random.m3u";

  # See scripts/beets-random.sh.
  beetsRandom = pkgs.writeShellApplication {
    name = "beets-random";
    runtimeInputs = [config.programs.beets.package pkgs.coreutils pkgs.gnused];
    runtimeEnv.RANDOM_PLAYLIST = randomPlaylist;
    text = builtins.readFile ./scripts/beets-random.sh;
  };
in {
  # The Rockbox player sync scripts: rockbox-sync, rockbox-scrobble and
  # rockbox-playlists.
  imports = [(import ./rockbox.nix {inherit randomPlaylist;})];

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
        "playlist" # keeps hand-made playlists' paths current as beets moves files
        "listenbrainz" # `beet lbimport` pulls listen counts into the library
        "replaygain" # loudness tags Rockbox levels playback by
        "ftintitle" # "feat. X" into the title, so one artist stays one artist
        "random" # `beet random`, behind the daily Random playlist
        "badfiles" # `beet bad` checks files with flac before they reach the card
        "mbsync" # `beet mbsync` re-pulls tags from MusicBrainz
        "missing" # `beet missing` lists tracks absent from partial albums
        "unimported" # `beet unimported` lists files beets doesn't track
        "edit" # `beet edit` opens tags in $EDITOR
      ];

      # Genre tags from MusicBrainz, for browsing by genre on the Rockbox.
      musicbrainz.genres = true;

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

      # nixpkgs puts ffmpeg on the beet wrapper's PATH for this plugin; the
      # default gstreamer backend has no such wiring. `auto` tags on import.
      replaygain = {
        backend = "ffmpeg";
        auto = true;
      };

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
        # MPD's playlist directory: .m3u files whose entries read artists/…,
        # relative to its music directory. rockbox-playlists rewrites them as
        # ../artists/… in .m3u8 files for the card.
        playlist_dir = "~/Music/playlists";
        relative_to = "~/Music";
        playlists = [
          {
            name = "Recently Added.m3u";
            query = "added:-1m..";
          }
          {
            # Negated, so tracks with no recorded listens (no field) match.
            name = "Underplayed.m3u";
            query = "^listenbrainz_play_count:6..";
          }
          {
            name = "Unplayed.m3u";
            query = "^listenbrainz_play_count:1..";
          }
        ];
      };

      # Rewrites entries in the hand-made playlists when beets moves or
      # removes a track, so a re-tag doesn't leave them pointing at nothing.
      playlist = {
        auto = true;
        playlist_dir = "~/Music/playlists";
        relative_to = "~/Music";
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

  # Daily: pull ListenBrainz plays, then rebuild every playlist and draw a new
  # Random one. splupdate runs unconditionally because `auto` only rewrites
  # playlists a changed track matches, so a quiet day would never age
  # anything out of Recently Added.
  # Linux only, since the one consumer is the NAS MPD, which hester-prynne
  # feeds through the Syncthing playlists folder.
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
        ${lib.getExe beetsRandom}
      '');
    };
  };

  systemd.user.timers.beets-refresh = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Daily ListenBrainz import and playlist rebuild";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };
}
