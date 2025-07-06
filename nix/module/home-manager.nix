{ ... }:
{
  programs.home-manager.enable = true;
  xdg.enable = true;
  
  imports = [
    ./gh
    ./git
    ./gnupg
    ./karabiner
    ./nvim
    ./pkgs.nix
    ./tmuxinator
  ];
}
