{
  description = "entorenee's Nix environment";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix modules for macOS such as homebrew, launchd, users, networking etc.
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { home-manager, darwin, ... }:
    let
      system = "aarch64-darwin";
    in
    {
      darwinConfigurations."entorenee" = darwin.lib.darwinSystem {
        inherit system;
        modules = [
          ./darwin-configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = false;
            home-manager.useUserPackages = true;
            # TODO: This will need to be dynamic for mnultiple profiles in the future
            home-manager.users."skyler.lemay" = import ./home.nix;
          }
        ];
      };
    };
}
