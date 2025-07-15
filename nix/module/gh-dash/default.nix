{ lib, profile, ... }:
let
  isWorkProfile = profile == "work";
  configPath = if isWorkProfile then ./config/work-config.yml else ./config/starter-config.yml;
in
{
  programs.gh-dash = {
    enable = true;
  };

  xdg.configFile."gh-dash/config.yml".source = lib.mkForce configPath;
}
