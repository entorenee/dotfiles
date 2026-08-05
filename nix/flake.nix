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

    # The mkDarwin/mkNixos/mkHome helpers live in ./lib/, each parameterized
    # on exactly the flake inputs it needs — see §4's target layout.
    mkHomeManagerArgs = import ./lib/home-manager-args.nix {
      inherit lib navi-cheatsheets private-assets tmux-powerkit worktrunk;
    };

    inherit
      (import ./lib/darwin.nix {
        inherit darwin home-manager home-manager-config worktrunk baseOverlays mkHomeManagerArgs;
      })
      mkDarwinConfig
      mkDarwinHost
      ;

    inherit
      (import ./lib/home.nix {
        inherit nixpkgs home-manager home-manager-config baseOverlays mkHomeManagerArgs worktrunk;
      })
      mkHomeManagerConfig
      mkHomeHost
      ;

    mkNixosConfig = import ./lib/nixos.nix {
      inherit nixpkgs home-manager lib nixos-hardware yubikey-guide baseOverlays mkHomeManagerArgs worktrunk;
    };
  in {
    darwinConfigurations = {
      fw-skyler = mkDarwinHost ./hosts/darwin/fw-skyler;
      lyra-sylvertongue = mkDarwinHost ./hosts/darwin/lyra-sylvertongue.nix;
    };

    homeConfigurations = {
      hester-prynne = mkHomeHost ./hosts/home/hester-prynne;
    };

    nixosConfigurations = {
      hub = mkNixosConfig "aarch64-linux" ./hosts/nixos/hub.nix "skyler";
      airgap = mkNixosConfig "aarch64-linux" ./hosts/nixos/airgap.nix null;
      uptime = mkNixosConfig "aarch64-linux" ./hosts/nixos/uptime.nix null;
    };
  };
}
