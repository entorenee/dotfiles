{ ... }:
{
  asana = {
    serviceConfig = {
      Label = "Asana";
      Program = "/Applications/Asana.app/Contents/MacOS/Asana";
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
  bitwarden = {
    serviceConfig = {
      Label = "Bitwarden";
      Program = "/Applications/Bitwarden.app/Contents/MacOS/Bitwarden";
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
  google-chrome = {
    serviceConfig = {
      Label = "Chrome";
      Program = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
  google-drive = {
    serviceConfig = {
      Label = "GDrive";
      Program = "/Applications/Google Drive.app/Contents/MacOS/Google Drive";
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
  slack = {
    serviceConfig = {
      Label = "Slack";
      Program = "/Applications/Slack.app/Contents/MacOS/Slack";
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
}
