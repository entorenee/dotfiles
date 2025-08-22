{...}: {
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
  google-chrome = {
    serviceConfig = {
      Label = "Chrome";
      ProgramArguments = ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"];
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
}
