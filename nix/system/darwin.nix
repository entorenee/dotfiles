{
  home-manager,
  darwin,
  nixpkgs,
  username,
  profile,
  ...
}:
system:
let
  lib = nixpkgs.lib;
  pkgs = nixpkgs.legacyPackages.${system};
  home-manager-config = import ../module/home-manager.nix { inherit lib username pkgs profile; };
  homebrew-config = import ../module/homebrew/default.nix { inherit lib username profile; };
  system-config = import ../module/system-configuration.nix { inherit username; };
in
darwin.lib.darwinSystem {
  inherit system;

   modules = [
      # home-manager
      home-manager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = false;
        home-manager.useUserPackages = true;
        home-manager.users."${username}" = home-manager-config;
        home-manager.backupFileExtension = "backup";
      }

      # Shareable system level configuration
      system-config

      # Homebrew configuration
      homebrew-config

      # System settings
      {
        system = {
          primaryUser = username;
          defaults = {
            controlcenter = {
              BatteryShowPercentage = true;
              Bluetooth = true;
            };
            CustomUserPreferences = {
              "com.apple.trackpad" = {
                scaling = 2;
              };
            };
            dock = {
              autohide = true;
              orientation = "left";
              # TODO: come back to setting this up.
              # persistent-apps = [
              # ];
              showhidden = true;
              tilesize = 40;
              wvous-tr-corner = 4;
              wvous-br-corner = 2;
            };
            finder = {
              AppleShowAllExtensions = true;
              AppleShowAllFiles = true;
              FXDefaultSearchScope = "SCcf"; # Default Search to current folder
              FXEnableExtensionChangeWarning = false;
              FXPreferredViewStyle = "Nlsv"; # Default to List View
              FXRemoveOldTrashItems = true;
              NewWindowTarget = "Documents";
              ShowExternalHardDrivesOnDesktop = false;
              ShowPathbar = true;
            };
            menuExtraClock = {
              Show24Hour = true;
            };
            NSGlobalDomain = {
              AppleInterfaceStyle = "Dark";
              AppleMeasurementUnits = "Centimeters";
              AppleMetricUnits = 1;
              AppleShowAllExtensions = true;
              AppleShowAllFiles = true;
              AppleShowScrollBars = "Always";
              AppleTemperatureUnit = "Celsius";
              InitialKeyRepeat = 10;
              KeyRepeat = 2;
              NSAutomaticDashSubstitutionEnabled = false;
              NSAutomaticPeriodSubstitutionEnabled = false;
              NSAutomaticQuoteSubstitutionEnabled = false;
              NSAutomaticSpellingCorrectionEnabled = false;
              NSDocumentSaveNewDocumentsToCloud = false;
              _HIHideMenuBar = true;
            };
            screensaver = {
              askForPassword = true;
              askForPasswordDelay = 0;
            };
            trackpad = {
              Clicking = true;
              Dragging = true;
              TrackpadThreeFingerTapGesture = 0;
            };
          };
          keyboard = {
            enableKeyMapping = true;
            remapCapsLockToEscape = true;
          };
        };
        time = {
          timeZone = "America/Los_Angeles";
        };
      }
    ];
}
