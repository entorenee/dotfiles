{...}: {
  # Imported from roles/home/personal-desktop.nix, not from a tier role: this is
  # a personal GUI desktop's password manager, not something a class of machine
  # wants.
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
