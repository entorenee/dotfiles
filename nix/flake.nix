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
      url = "path:./modules/home/navi";
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

    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    nixos-hardware.url = "github:nixos/nixos-hardware";

    yubikey-guide = {
      url = "github:drduh/yubikey-guide";
      flake = false;
    };
  };

  outputs = {
    home-manager,
    darwin,
    nixpkgs,
    nixpkgs-stable,
    navi-cheatsheets,
    nixos-hardware,
    private-assets,
    tmux-powerkit,
    worktrunk,
    yubikey-guide,
    ...
  }: let
    lib = nixpkgs.lib;
    # Every current machine is a graphical workstation, so they all take the
    # `gui` role; it stacks onto `cli` and `base`. Headless hosts (the Pis) will
    # import a lower role instead of gating pieces off.
    home-manager-config = ./roles/home/gui.nix;

    mkHomeManagerArgs = system: username: {
      inherit lib username private-assets tmux-powerkit worktrunk;
      navi-cheatsheets = navi-cheatsheets.packages.${system}.default;
    };

    # `user` is a path into ./users — persona is selected by importing a
    # directory, not by threading a string down to every module that cares.
    # `extraHomeImports` lets a host opt into persona pieces that aren't part
    # of that persona's portable base (e.g. the personal desktop-only add-ons
    # in users/personal/desktop.nix) without forcing them on every host that
    # imports the persona — see docs/local/plans/nix-architecture-redesign.md §4c.
    mkDarwinConfig = username: user: system: extraHomeImports:
      import ./system/darwin.nix {
        inherit darwin home-manager home-manager-config username user worktrunk extraHomeImports;
        homeManagerArgs = mkHomeManagerArgs system username;
      }
      system;

    # A host file states which machine this is — username, persona directory,
    # system triple, and any extra home-manager imports it opts into — so the
    # flake output key is the hostname rather than the persona name.
    mkDarwinHost = path: let
      host = import path;
    in
      mkDarwinConfig host.username host.user host.system (host.extraHomeImports or []);

    mkHomeHost = path: let
      host = import path;
    in
      mkHomeManagerConfig host.username host.user host.system (host.extraHomeImports or []);

    mkNixosConfig = system: module:
      nixpkgs-stable.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit nixos-hardware yubikey-guide;};
        modules = [module];
      };

    mkHomeManagerConfig = username: user: system: extraHomeImports: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {inherit worktrunk;};
        modules =
          [
            home-manager-config
            (user + "/home.nix")
          ]
          ++ extraHomeImports
          ++ [
            worktrunk.homeModules.default
            {
              home.username = username;
              home.homeDirectory = "/home/${username}";
              _module.args = mkHomeManagerArgs system username;
            }
          ];
      };
  in {
    darwinConfigurations = {
      fw-skyler = mkDarwinHost ./hosts/darwin/fw-skyler;
      lyra-sylvertongue = mkDarwinHost ./hosts/darwin/lyra-sylvertongue.nix;
    };

    homeConfigurations = {
      hester-prynne = mkHomeHost ./hosts/home/hester-prynne.nix;
    };

    nixosConfigurations = {
      hub = mkNixosConfig "aarch64-linux" ./hosts/nixos/hub.nix;
      airgap = mkNixosConfig "aarch64-linux" ./hosts/nixos/airgap.nix;
      uptime = mkNixosConfig "aarch64-linux" ./hosts/nixos/uptime.nix;
    };
  };
}
