{
  home-manager,
  darwin,
  nixpkgs,
  homeManagerArgs,
  home-manager-config,
  username,
  profile,
  ...
}: system: let
  lib = nixpkgs.lib;
  homebrew-config = import ../module/homebrew/default.nix {inherit lib profile;};
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
    "/Applications/OrcaSlicer.app"
  ];
  workDock = [
    "/Applications/Ghostty.app"
    "/Applications/Obsidian.app"
    "/Applications/Asana.app"
    "/Applications/Slack.app"
    "/Applications/Firefox.app"
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
          _module.args = homeManagerArgs;
        };
        home-manager.backupFileExtension = "hm-backup";
      }

      # Homebrew configuration
      homebrew-config

      # System settings
      {
        security.pam.services.sudo_local = {
          enable = true;
          touchIdAuth = true;
          reattach = true;
        };

        ids.gids.nixbld = 350;

        users.users.${username}.home = "/Users/${username}";

        nix = {
          enable = false;
          settings.experimental-features = "nix-command flakes";
        };

        nixpkgs.hostPlatform = system;

        system = {
          stateVersion = 4;
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
              TrackpadThreeFingerTapGesture = 0;
            };
            WindowManager = {
              EnableStandardClickToShowDesktop = false;
            };
          };
          keyboard = {
            enableKeyMapping = true;
            remapCapsLockToEscape = true;
          };
        };

        launchd.user.agents = launch-agents-config;

        time.timeZone = "America/Los_Angeles";
      }
    ];
  }
