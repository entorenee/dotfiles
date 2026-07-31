{
  lib,
  profile,
  ...
}: let
  isPersonalProfile = profile == "personal";
in {
  programs.keepassxc = lib.mkIf isPersonalProfile {
    enable = true;
    autostart = true;
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
        LaunchAtStartup = true;
        MinimizeOnClose = true;
        MinimizeOnStartup = true;
        ShowTrayIcon = true;
        TrayIconAppearance = "monochrome-light";
      };
    };
  };
}
