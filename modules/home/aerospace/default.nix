{
  config,
  lib,
  pkgs,
  ...
}: let
  aerospacePath = "${config.home.homeDirectory}/dotfiles/modules/home/aerospace/config";
in
  # AeroSpace is a macOS-only GUI app installed as a Homebrew cask (see
  # ../../darwin/homebrew/default.nix), so this module is a no-op on Linux.
  lib.mkIf pkgs.stdenv.isDarwin {
    # Out-of-store symlink (same idiom as ghostty/karabiner) rather than a store
    # copy: keybinding tweaks in aerospace.toml then go live via
    # `aerospace reload-config` with no rebuild — which matters here because a
    # rebuild requires quitting every running Claude Code session first.
    # AeroSpace only ever reads this file, so nothing tries to write the symlink.
    xdg.configFile."aerospace".source = config.lib.file.mkOutOfStoreSymlink aerospacePath;
  }
