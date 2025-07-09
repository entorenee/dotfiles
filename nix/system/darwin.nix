{
  home-manager,
  darwin,
  username,
  profile,
  ...
}:
system:
let
  home-manager-config = import ../module/home-manager.nix { inherit profile; };
  homebrew = import ../module/homebrew.nix { inherit profile; };
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
