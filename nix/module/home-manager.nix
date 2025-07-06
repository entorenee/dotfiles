{ ... }:
{
  programs.home-manager.enable = true;
  xdg.enable = true;
  
  imports = [
    ./gh
    ./git
    ./karabiner
    ./nvim
    ./pkgs.nix
    ./tmuxinator
  ];
}
