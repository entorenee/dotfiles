{ ... }:
{
  programs.home-manager.enable = true;
  xdg.enable = true;
  
  imports = [
    ./fonts
    ./gh
    ./git
    ./gnupg
    ./nvim
    ./pkgs.nix
    ./starship
    ./tmux
    ./tmuxinator
    ./zsh
  ];
}
