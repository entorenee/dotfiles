{pkgs, ...}: {
  home.packages = [pkgs.smug];
  xdg.configFile."smug".source = ./projects;
}
