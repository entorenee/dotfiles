{ profile, ... }:
let
  shared = {
    elgatoControlCenter = {
      serviceConfig = {
        Label = "ElgatoControlCenter";
        ProgramArguments = ["/Applications/Elgato Control Center.app/Contents/MacOS/Elgato Control Center"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
    rectangle = {
      serviceConfig = {
        Label = "Rectangle";
        ProgramArguments = ["/Applications/Rectangle.app/Contents/MacOS/Rectangle"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
  };

  profileConfig = if builtins.pathExists ./${profile}.nix
    then import ./${profile}.nix {}
    else {};
in
shared // profileConfig
