{
  home-manager,
  darwin,
  nixpkgs,
  navi-cheatsheets,
  private-assets,
  username,
  profile,
  ...
}: system: let
  lib = nixpkgs.lib;
  home-manager-config = import ../module/home-manager.nix;
  homebrew-config = import ../module/homebrew/default.nix {inherit lib profile;};
  system-config = import ../module/system-configuration.nix {inherit username;};
  launch-agents-config = import ../module/launch-agents/default.nix {inherit profile;};

  personalDock = [
    "/Applications/Ghostty.app"
    "/Applications/Obsidian.app"
    "/Applications/Firefox.app"
    "/Applications/Signal.app"
    "/Applications/Slack.app"
    "/Applications/Discord.app"
    "/Applications/KeePassXC.app"
    "/Applications/Proton Mail.app"
    "/Applications/ProtonVPN.app"
    "/Applications/Yubico Authenticator.app"
  ];
  workDock = [
    "/Applications/Ghostty.app"
    "/Applications/Obsidian.app"
    "/Applications/Asana.app"
    "/Applications/Slack.app"
    "/Applications/Google Chrome.app"
    "/Applications/TablePlus.app"
    "/Applications/Claude.app"
    "/Applications/Bitwarden.app"
  ];
  dockPersistentApps = {
    personal = personalDock;
    work = workDock;
  };
in
  darwin.lib.darwinSystem {
    inherit system;

    modules = [
      # home-manager
      home-manager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = false;
        home-manager.useUserPackages = true;
        home-manager.users."${username}" = {
          imports = [home-manager-config];
          _module.args = {
            inherit lib username profile private-assets;
            navi-cheatsheets = navi-cheatsheets.packages.${system}.default;
          };
        };
        home-manager.backupFileExtension = "backup";
      }

      # Shareable system level configuration
      system-config

      # Homebrew configuration
      homebrew-config

      # System settings
      {
        launchd.user.agents = launch-agents-config;
        system = {
          primaryUser = username;
          defaults = {
            controlcenter = {
              BatteryShowPercentage = true;
              Bluetooth = true;
            };
            CustomUserPreferences = {
              "com.apple.dock" = {
                size-immutable = true;
              };
              "com.apple.trackpad" = {
                scaling = 2;
              };
            };
            dock = {
              autohide = true;
              orientation = "left";
              persistent-apps = dockPersistentApps.${profile} or null;
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
              AppleICUForce24HourTime = true;
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
              _HIHideMenuBar = false;
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
