{randomPlaylist}: {
  config,
  lib,
  pkgs,
  ...
}: let
  # See scripts/rockbox-scrobble.sh.
  rockboxScrobble = pkgs.writeShellApplication {
    name = "rockbox-scrobble";
    runtimeInputs = [config.programs.beets.package pkgs.coreutils pkgs.curl pkgs.gnugrep pkgs.jq pkgs.yq-go];
    runtimeEnv.LISTENBRAINZ_SECRET = config.age.secrets.beets-listenbrainz.path;
    text = builtins.readFile ./scripts/rockbox-scrobble.sh;
  };

  # See scripts/rockbox-playlists.sh.
  rockboxPlaylists = pkgs.writeShellApplication {
    name = "rockbox-playlists";
    runtimeInputs = [pkgs.coreutils pkgs.diffutils pkgs.gawk pkgs.gnugrep pkgs.gnused];
    runtimeEnv.ROCKBOX_GENERATED_PLAYLISTS = lib.concatStringsSep "\n" (
      map (p: p.name) config.programs.beets.settings.smartplaylist.playlists ++ [randomPlaylist]
    );
    text = builtins.readFile ./scripts/rockbox-playlists.sh;
  };

  # See scripts/rockbox-sync.sh.
  rockboxSync = pkgs.writeShellApplication {
    name = "rockbox-sync";
    runtimeInputs = [config.programs.beets.package pkgs.coreutils pkgs.rsync rockboxScrobble rockboxPlaylists];
    runtimeEnv = {
      ROCKBOX_CONFIG = "${./rockbox}";
      ROCKBOX_BACKUP = "${config.home.homeDirectory}/dotfiles/modules/home/beets/rockbox-device";
    };
    text = builtins.readFile ./scripts/rockbox-sync.sh;
  };
in {
  home.packages = lib.mkIf pkgs.stdenv.isLinux [rockboxScrobble rockboxSync];
}
