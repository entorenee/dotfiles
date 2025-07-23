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
    { home-manager, darwin, nixpkgs, ... }:
    let
      mkDarwinConfig = username: profile: system: import ./system/darwin.nix {
        inherit
          home-manager
          darwin
          nixpkgs
          username
          profile
          ;
      } system;
    in
    {
      darwinConfigurations = {
        personal = mkDarwinConfig "skyler.lemay" "personal" "aarch64-darwin";
        work = mkDarwinConfig "fw-skylerlemay" "work" "aarch64-darwin";
      };
    };
}
