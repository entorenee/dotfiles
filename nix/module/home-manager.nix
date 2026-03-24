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
  sshModule = import ./ssh {inherit lib username pkgs profile;};
  isPersonalProfile = profile == "personal";

  personalPkgs = [
    ./keepassxc
    ./orca-slicer
  ];
in {
  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
  xdg.enable = true;
  targets.genericLinux.enable = true;

  imports =
    [
      ./alacritty
      ./bins
      ./cspell
      ./firefox
      ./fonts
      ./karabiner
      ./gh
      ghDashModule
      ./ghostty
      ./git
      ./gnupg
      ./lazygit
      ./navi
      ./nvim
      ./nvm
      pkgsModule
      sshModule
      ./starship
      ./tmux
      ./tmuxinator
      ./yamlfmt
      ./zsh
    ]
    ++ lib.optionals isPersonalProfile personalPkgs;
}
