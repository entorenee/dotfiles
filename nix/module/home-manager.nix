{ ... }:
{
  programs.home-manager.enable = true;
  xdg.enable = true;
  
  imports = [
    ./fonts.nix
    ./gh
    ./git
    ./gnupg
    ./karabiner
    ./nvim
    ./pkgs.nix
    ./tmuxinator
  ];
}
