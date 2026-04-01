{
  config,
  lib,
  pkgs,
  profile,
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
  ];
}
