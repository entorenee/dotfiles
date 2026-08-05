{...}: {
  # Imported from users/personal/home.nix, not from a role — the work machine
  # does not want KeePassXC at all.
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
