{
  config,
  lib,
  pkgs,
  ...
}: let
  rtkConfigPath = "${config.home.homeDirectory}/dotfiles/nix/module/rtk/config/config.toml";
in {
  # rtk (Rust Token Killer) — token-optimizing CLI proxy. Installed from
  # nixpkgs (was previously a Homebrew brew). The rtk-rewrite Claude hook lives
  # in the claude module; this module owns the binary and its config.
  home.packages = [pkgs.rtk];

  # Symlink the config to rtk's platform-specific location. macOS resolves to
  # ~/Library/Application Support/rtk/config.toml; Linux follows XDG.
  # mkOutOfStoreSymlink so edits to config.toml apply without a rebuild.
  home.file = lib.mkIf pkgs.stdenv.isDarwin {
    "Library/Application Support/rtk/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink rtkConfigPath;
  };

  xdg.configFile = lib.mkIf pkgs.stdenv.isLinux {
    "rtk/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink rtkConfigPath;
  };
}
