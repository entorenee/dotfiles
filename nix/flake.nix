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
      username = "skyler.lemay";
      darwin-system = import ./system/darwin.nix {
        inherit
          home-manager
          darwin
          username
          ;
      };
    in
    {
      darwinConfigurations = {
        entorenee = darwin-system "aarch64-darwin";
      };
    };
}
