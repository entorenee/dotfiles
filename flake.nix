{
  description = "entorenee's Nix environment";

  nixConfig = {
    warn-dirty = false;
  };

  inputs = {
    # Stable 26.05 across the board; freshness where it matters (claude-code)
    # comes from the nixpkgs-unstable escape hatch, not from tracking unstable.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix modules for macOS such as homebrew, launchd, users, networking etc.
    # Track the nix-darwin org's own 26.05 release branch, matching the
    # nixpkgs/home-manager pin — not the unmaintained lnl7 fork.
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets. All three `follows` are load-bearing: stock Nix on the Pis
    # fetches every locked input eagerly, so each unfollowed input is a full
    # extra fetch on a 512MB Zero — here a second nixpkgs and the lnl7
    # nix-darwin fork.
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "darwin";
      inputs.home-manager.follows = "home-manager";
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

    # No `private-assets` input. The private font repo is fetched by its only
    # consumer, modules/home/fonts, so hosts that never import that module
    # never authenticate to GitHub to evaluate. See that file for why.

    nixos-hardware.url = "github:nixos/nixos-hardware";

    yubikey-guide = {
      url = "github:drduh/yubikey-guide";
      flake = false;
    };
  };

  outputs = {
    agenix,
    home-manager,
    darwin,
    nixpkgs,
    nixpkgs-unstable,
    navi-cheatsheets,
    nixos-hardware,
    tmux-powerkit,
    worktrunk,
    yubikey-guide,
    ...
  }: let
    lib = nixpkgs.lib;

    # Universal rather than a per-host opt-in like overlays/pnpm-pin.nix,
    # because both serve a tier rather than named machines: claude-code-unstable
    # backs `programs.claude-code` in the `claude` module, and
    # agenix.overlays.default supplies `pkgs.agenix` for editing and rekeying
    # secrets — both reached through roles/home/cli.nix. Host-scoping would mean
    # re-listing an overlay every time a host moved up a tier. Inert below that
    # tier: `uptime` takes minimal.nix, which imports neither.
    baseOverlays = [
      (import ./overlays/claude-code-unstable.nix {inherit nixpkgs-unstable;})
      agenix.overlays.default
    ];

    mkHomeManagerArgs = import ./lib/home-manager-args.nix {
      inherit lib navi-cheatsheets tmux-powerkit worktrunk;
    };

    inherit
      (import ./lib/darwin.nix {
        inherit darwin home-manager worktrunk baseOverlays mkHomeManagerArgs;
      })
      mkDarwinConfig
      mkDarwinHost
      ;

    inherit
      (import ./lib/home.nix {
        inherit nixpkgs home-manager baseOverlays mkHomeManagerArgs worktrunk;
      })
      mkHomeManagerConfig
      mkHomeHost
      ;

    inherit
      (import ./lib/nixos.nix {
        inherit nixpkgs home-manager lib nixos-hardware yubikey-guide baseOverlays mkHomeManagerArgs worktrunk;
      })
      mkNixosConfig
      mkNixosHost
      ;
  in {
    darwinConfigurations = {
      fw-skyler = mkDarwinHost ./hosts/darwin/fw-skyler;
      lyra-silvertongue = mkDarwinHost ./hosts/darwin/lyra-silvertongue.nix;
    };

    homeConfigurations = {
      hester-prynne = mkHomeHost ./hosts/home/hester-prynne;
    };

    nixosConfigurations = {
      hub = mkNixosHost ./hosts/nixos/hub;
      airgap = mkNixosHost ./hosts/nixos/airgap;
      uptime = mkNixosHost ./hosts/nixos/uptime;
    };
  };
}
