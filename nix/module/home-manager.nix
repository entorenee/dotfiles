{
  lib,
  username,
  pkgs,
  profile,
  ...
}:
let
  ghDashModule = import ./gh-dash { inherit lib profile; };
  pkgsModule = import ./pkgs.nix { inherit lib pkgs profile; };
  sshModule = import ./ssh { inherit lib username profile; };
in
{
  programs.home-manager.enable = true;
  home.stateVersion = "24.05";
  xdg.enable = true;
  
  imports = [
    ./fonts
    ./gh
    ghDashModule
    ./git
    ./gnupg
    ./nvim
    pkgsModule
    sshModule
    ./starship
    ./tmux
    ./tmuxinator
    ./zsh
  ];
}
