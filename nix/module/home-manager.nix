{ ... }:
{
  programs.home-manager.enable = true;
  xdg.enable = true;
  
  imports = [
    ./fonts
    ./gh
    ./git
    ./gnupg
    ./karabiner
    ./nvim
    ./pkgs.nix
    ./starship
    ./tmux
    ./tmuxinator
    ./zsh
  ];
}
