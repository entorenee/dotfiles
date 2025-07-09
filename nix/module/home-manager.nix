{ ... }:
{
  programs.home-manager.enable = true;
  home.stateVersion = "24.05";
  xdg.enable = true;
  
  imports = [
    ./fonts
    ./gh
    ./git
    ./gnupg
    ./nvim
    ./pkgs.nix
    ./starship
    ./tmuxinator
    ./zsh
  ];
}
