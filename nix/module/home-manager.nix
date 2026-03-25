{
  config,
  lib,
  username,
  pkgs,
  profile,
  ...
}: let
  ghDashModule = import ./gh-dash {inherit config lib profile;};
  pkgsModule = import ./pkgs.nix {inherit lib pkgs profile;};
  isPersonalProfile = profile == "personal";

  personalModules = [
    ./keepassxc
    ./orca-slicer
  ];
in {
  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
  xdg.enable = true;
  targets.genericLinux.enable = pkgs.stdenv.isLinux;

  imports =
    [
      ./alacritty
      ./bins
      ./cspell
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
      ./ssh
      ./starship
      ./tmux
      ./tmuxinator
      ./yamlfmt
      ./zsh
    ]
    ++ lib.optionals isPersonalProfile personalModules;
}
