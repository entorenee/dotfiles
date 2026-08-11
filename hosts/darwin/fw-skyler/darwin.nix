{...}: {
  homebrew = {
    brews = [
      "hookdeck/hookdeck/hookdeck"
      "mysql"
      "vercel-cli"
    ];

    casks = [
      "android-studio"
      "asana"
      "bitwarden"
      "google-chrome"
      "google-drive"
      "granola"
      "loom"
      "surfshark"
      "tableplus"
    ];
  };

  launchd.user.agents = {
    asana = {
      serviceConfig = {
        Label = "Asana";
        ProgramArguments = ["/Applications/Asana.app/Contents/MacOS/Asana"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
    bitwarden = {
      serviceConfig = {
        Label = "Bitwarden";
        ProgramArguments = ["/Applications/Bitwarden.app/Contents/MacOS/Bitwarden"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
    google-drive = {
      serviceConfig = {
        Label = "GDrive";
        ProgramArguments = ["/Applications/Google Drive.app/Contents/MacOS/Google Drive"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
    slack = {
      serviceConfig = {
        Label = "Slack";
        ProgramArguments = ["/Applications/Slack.app/Contents/MacOS/Slack"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
  };

  system.defaults.dock.persistent-apps = [
    "/Applications/Ghostty.app"
    "/Applications/Obsidian.app"
    "/Applications/Asana.app"
    "/Applications/Slack.app"
    "/Applications/Firefox.app"
    "/Applications/TablePlus.app"
    "/Applications/Claude.app"
    "/Applications/Bitwarden.app"
  ];
}
