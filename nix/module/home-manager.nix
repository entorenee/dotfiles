{ ... }:
{
  programs.home-manager.enable = true;
  xdg.enable = true;
  
  imports = [
    ./gh
    ./git
    ./nvim
    ./pkgs.nix
    ./tmuxinator
  ];
}
