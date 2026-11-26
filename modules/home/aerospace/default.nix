{
  config,
  lib,
  pkgs,
  ...
}:
# macOS-only GUI app, installed as a Homebrew cask.
lib.mkIf pkgs.stdenv.isDarwin {
  # Out-of-store symlink rather than a store copy so keybinding tweaks go live
  # via `aerospace reload-config` with no rebuild — which matters because a
  # rebuild requires quitting every running Claude Code session first.
  # AeroSpace only reads this file, so nothing writes to the symlink.
  xdg.configFile."aerospace".source = config.lib.dotfiles.link ./config;
}
