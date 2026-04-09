{
  description = "entorenee's Nix environment";

  nixConfig = {
    warn-dirty = false;
  };

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

    tmux-powerkit.url = "github:fabioluciano/tmux-powerkit";

    worktrunk = {
      url = "github:max-sixty/worktrunk";
      inputs.nixpkgs.follows = "nixpkgs";
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
    tmux-powerkit,
    worktrunk,
    ...
  }: let
    lib = nixpkgs.lib;
    home-manager-config = import ./module/home-manager.nix;

    mkHomeManagerArgs = system: username: profile: {
      inherit lib username profile private-assets tmux-powerkit worktrunk;
      navi-cheatsheets = navi-cheatsheets.packages.${system}.default;
    };

    mkDarwinConfig = username: profile: system:
      import ./system/darwin.nix {
        inherit darwin home-manager nixpkgs home-manager-config username profile;
        homeManagerArgs = mkHomeManagerArgs system username profile;
      }
      system;

    mkHomeManagerConfig = username: profile: system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {inherit profile;};
        modules = [
          home-manager-config
          {
            home.username = username;
            home.homeDirectory = "/home/${username}";
            _module.args = mkHomeManagerArgs system username profile;
          }
        ];
      };
  in {
    darwinConfigurations = {
      personal = mkDarwinConfig "skyler.lemay" "personal" "aarch64-darwin";
      work = mkDarwinConfig "fw-skylerlemay" "work" "aarch64-darwin";
    };

    homeConfigurations = {
      "personal@linux" = mkHomeManagerConfig "skyler.lemay" "personal" "x86_64-linux";
    };
  };
}
