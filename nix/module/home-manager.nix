{
  config,
  lib,
  pkgs,
  profile,
  worktrunk,
  ...
}: let
  claudeModule = import ./claude {inherit config lib profile;};
  ghDashModule = import ./gh-dash {inherit config lib profile;};
  pkgsModule = import ./pkgs.nix {inherit lib pkgs profile;};
  keepassxcModule = import ./keepassxc {inherit config lib profile;};
  orcaSlicerModule = import ./orca-slicer {inherit config lib pkgs profile;};
in {
  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
  xdg.enable = true;
  targets.genericLinux.enable = pkgs.stdenv.isLinux;

  # Suppress system-installed autostart entries that degrade the user systemd
  # session on this machine (System76 HiDPI daemon, NVIDIA settings).
  # User-level Hidden=true overrides prevent the XDG autostart generator from
  # producing units at all; masking the generated units doesn't work because
  # their filenames use \x2d escaping that doesn't match plain-dash mask files.
  xdg.configFile = lib.optionalAttrs pkgs.stdenv.isLinux {
    "autostart/hidpi-daemon.desktop".text = "[Desktop Entry]\nHidden=true\n";
    "autostart/hidpi-frontend.desktop".text = "[Desktop Entry]\nHidden=true\n";
    "autostart/nvidia-settings-autostart.desktop".text = "[Desktop Entry]\nHidden=true\n";
    # Reset XDG_DATA_DIRS to a canonical single-copy value in the systemd user
    # environment. 10-home-manager.conf (from targets.genericLinux) uses
    # ${XDG_DATA_DIRS:+:$XDG_DATA_DIRS} which accumulates duplicates when the
    # systemd user manager inherits a non-empty XDG_DATA_DIRS from PAM or a
    # previous session. This file (processed later alphabetically) resets it to
    # a clean baseline so apps launched as systemd user services see 1× paths.
    "environment.d/50-xdg-dedup.conf".text = ''
      XDG_DATA_DIRS=/nix/var/nix/profiles/default/share:${config.home.homeDirectory}/.nix-profile/share:/usr/share/ubuntu:/usr/local/share:/usr/share:/var/lib/snapd/desktop
    '';
  };

  imports = [
    ./alacritty
    ./bins
    claudeModule
    ./docker
    ./firefox
    ./fonts
    ./gh
    ghDashModule
    ./ghostty
    ./git
    ./gnupg
    ./karabiner
    ./lazygit
    ./navi
    ./nvim
    ./npm
    ./nvm
    pkgsModule
    ./rtk
    ./smug
    ./ssh
    ./starship
    ./tmux
    ./tmuxinator
    ./typos
    ./yamlfmt
    ./zsh
    keepassxcModule
    orcaSlicerModule
    ./worktrunk
  ];
}
