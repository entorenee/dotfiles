{
  description = "entorenee's Nix environment";

  nixConfig = {
    warn-dirty = false;
  };

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    # Stable 26.05 across the board.
    # nixpkgs, home-manager, and darwin release branches move together.
    # Package freshness where it matters (claude-code) comes from the
    # nixpkgs-unstable escape hatch below, not from tracking unstable wholesale.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix modules for macOS such as homebrew, launchd, users, networking etc.
    # Moved from lnl7/nix-darwin (unmaintained fork origin) to the nix-darwin
    # org's own 26.05 release branch, matching the nixpkgs/home-manager pin.
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
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
    nixpkgs-unstable,
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

    # Applied to every host regardless of persona — every current and planned
    # host imports the `claude` module via `roles/home/cli.nix`, so the
    # unstable escape hatch for it (see §6.2) is not a per-host opt-in like
    # `nix/overlays/{protonmail-desktop,pnpm-pin}.nix`.
    baseOverlays = [(import ./overlays/claude-code-unstable.nix {inherit nixpkgs-unstable;})];

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
    # `overlays` is the same idea applied to nix/overlays/: a list of overlay
    # functions this specific host wants (see §6.3), not a set applied globally.
    mkDarwinConfig = username: user: system: extraHomeImports: overlays:
      import ./system/darwin.nix {
        inherit darwin home-manager home-manager-config username user worktrunk extraHomeImports;
        overlays = baseOverlays ++ overlays;
        homeManagerArgs = mkHomeManagerArgs system username;
      }
      system;

    # A host file states which machine this is — username, persona directory,
    # system triple, and any extra home-manager imports / overlays it opts
    # into — so the flake output key is the hostname rather than the persona
    # name.
    mkDarwinHost = path: let
      host = import path;
    in
      mkDarwinConfig host.username host.user host.system (host.extraHomeImports or []) (host.overlays or []);

    mkHomeHost = path: let
      host = import path;
    in
      mkHomeManagerConfig host.username host.user host.system (host.extraHomeImports or []) (host.overlays or []);

    # `homeManagerUser` is `null` for a NixOS host with no home-manager (the
    # airgap/uptime Pis, for now — see redesign doc §8 step 5 / open question
    # 3), or a username to wire up `roles/home/cli.nix` the same way the
    # Darwin/home hosts wire `roles/home/gui.nix`: same `_module.args`, same
    # `worktrunk.homeModules.default` import. `my.dotfiles.mutable = false`
    # here (not per-host) so any future Pi added this way is immutable by
    # default too, not just `hub` — see §6.1.
    mkNixosConfig = system: module: homeManagerUser:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit nixos-hardware yubikey-guide;};
        modules =
          [module]
          ++ lib.optionals (homeManagerUser != null) [
            home-manager.nixosModules.home-manager
            {
              # `useGlobalPkgs = true` means these must be set here at the
              # NixOS system level, same as system/darwin.nix's "System
              # settings" block — a home-manager module can't set either once
              # there's no separate pkgs left for it to configure (§6.3).
              nixpkgs.overlays = baseOverlays;
              nixpkgs.config.allowUnfree = true;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${homeManagerUser} = {
                imports = [./roles/home/cli.nix worktrunk.homeModules.default];
                my.dotfiles.mutable = false;
                _module.args = mkHomeManagerArgs system homeManagerUser;
              };
            }
          ];
      };

    mkHomeManagerConfig = username: user: system: extraHomeImports: overlays: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = baseOverlays ++ overlays;
        config.allowUnfree = true;
      };
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
      hub = mkNixosConfig "aarch64-linux" ./hosts/nixos/hub.nix "skyler";
      airgap = mkNixosConfig "aarch64-linux" ./hosts/nixos/airgap.nix null;
      uptime = mkNixosConfig "aarch64-linux" ./hosts/nixos/uptime.nix null;
    };
  };
}
