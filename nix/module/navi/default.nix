{
  pkgs,
  lib,
  config,
  navi-cheatsheets ? null,
  ...
}:
with lib; {
  programs.navi = {
    enable = true;
    enableZshIntegration = true;
    settings = mkIf (navi-cheatsheets != null) {
      cheats = {
        paths = ["${config.xdg.dataHome}/navi/cheats"];
      };
    };
  };

  # Symlink cheatsheets to XDG data directory (navi's default location)
  xdg.dataFile = mkIf (navi-cheatsheets != null) {
    "navi/cheats" = {
      source = navi-cheatsheets;
      recursive = true;
    };
  };

  home.packages = with pkgs; [
    tldr
  ];
}
