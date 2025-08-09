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

    # Custom navi cheatsheets
    navi-cheatsheets = {
      url = "path:./module/navi";
    };

    # Private assets - for initial setup without SSH, use:
    # --override-input private-assets 'path:/dev/null'
    private-assets = {
      url = "git+ssh://git@github.com/entorenee/dotfiles-private-assets.git";
      flake = false;
    };
  };

  outputs = {
    home-manager,
    darwin,
    nixpkgs,
    navi-cheatsheets,
    private-assets,
    ...
  }: let
    mkDarwinConfig = username: profile: system:
      import ./system/darwin.nix {
        inherit
          home-manager
          darwin
          nixpkgs
          navi-cheatsheets
          private-assets
          username
          profile
          ;
      }
      system;
  in {
    darwinConfigurations = {
      personal = mkDarwinConfig "skyler.lemay" "personal" "aarch64-darwin";
      work = mkDarwinConfig "fw-skylerlemay" "work" "aarch64-darwin";
    };
  };
}
