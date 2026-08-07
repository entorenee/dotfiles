{...}: {
  # Imported from roles/home/personal-desktop.nix, not from a tier role —
  # fw-skyler and a headless personal Pi both do not want KeePassXC.
  programs.keepassxc = {
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
