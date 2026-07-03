{
  lib,
  profile,
  ...
}: let
  isPersonalProfile = profile == "personal";
in {
  programs.keepassxc = lib.mkIf isPersonalProfile {
    enable = true;
    settings = {
      General = {
        AutoSaveAfterEveryChange = false;
        ConfigVersion = 2;
      };
      Browser = {
        Enabled = true;
      };
      GUI = {
        ApplicationTheme = "dark";
        HidePasswords = false;
        LaunchAtStartup = true;
        MinimizeOnStartup = true;
        TrayIconAppearance = "monochrome-light";
      };
    };
  };
}
