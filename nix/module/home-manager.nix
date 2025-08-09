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
  sshModule = import ./ssh {inherit lib username profile;};
in {
  programs.home-manager.enable = true;
  home.stateVersion = "24.05";
  xdg.enable = true;

  imports = [
    ./cspell
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
    ./zsh
  ];
}
