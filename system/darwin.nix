{
  home-manager,
  darwin,
  homeManagerArgs,
  username,
  worktrunk,
  homeImports,
  darwinImports ? [],
  overlays,
  ...
}: system:
# The two import lists split along module systems: `darwinImports` carries
# nix-darwin options (Homebrew, launch agents, the Dock), `homeImports` carries
# home-manager ones. See ../lib/darwin.nix for where they come from.
darwin.lib.darwinSystem {
  inherit system;

  modules =
    [
      # home-manager
      home-manager.darwinModules.home-manager
      {
        # Shares the system's pkgs instance (single eval, and the
        # nixpkgs.overlays/config set below reach home-manager automatically —
        # no separate nixpkgs block needed here).
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users."${username}" = {
          imports = homeImports ++ [worktrunk.homeModules.default];
          _module.args = homeManagerArgs;
        };
        home-manager.backupFileExtension = "hm-backup";
      }

      ../modules/darwin/homebrew
      ../modules/darwin/launch-agents
    ]
    ++ darwinImports
    ++ [
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

        nixpkgs = {
          hostPlatform = system;
          inherit overlays;
          config.allowUnfree = true;
        };

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

        time.timeZone = "America/Los_Angeles";
      }
    ];
}
