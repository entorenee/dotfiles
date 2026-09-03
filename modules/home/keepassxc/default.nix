{
  lib,
  pkgs,
  ...
}: {
  programs.keepassxc = {
    enable = true;

    # Darwin provides package via Homebrew
    package = lib.mkIf pkgs.stdenv.isDarwin null;

    autostart = !pkgs.stdenv.isDarwin;
    settings = {
      General = {
        AutoSaveAfterEveryChange = false;
        ConfigVersion = 2;
        HideWindowOnCopy = true;
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

      Security = {
        ClearClipboardTimeout = 20;
      };
    };
  };
}
