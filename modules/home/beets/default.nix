{...}: let
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
in {
  # Music library manager: tags from MusicBrainz, then files tracks into
  # ~/Music by the path templates below. Every path component is kebab-case,
  # e.g. cheap-perfume/2019-burn-it-down/01-put-the-devil-to-bed.flac
  programs.beets = {
    enable = true;

    settings = {
      directory = "~/Music";

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
      ];

      import = {
        write = true;
        # Copy, not move: originals stay put until the result has been checked.
        # Pass `-m` on the command line to move instead.
        copy = true;
        move = false;
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
    };
  };
}
