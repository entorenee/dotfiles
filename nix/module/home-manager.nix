{
  username,
  profile,
  ...
}:
let
  sshModule = import ./ssh { inherit username profile; };
in
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
    sshModule
    ./starship
    ./tmuxinator
    ./zsh
  ];
}
