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
  home-manager-config = import ../module/home-manager.nix { inherit lib username profile; };
  homebrew = import ../module/homebrew/default.nix { inherit lib profile; };
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
      homebrew

      # System settings
      {
        system = {
          primaryUser = username;
        };
      }
    ];
}
