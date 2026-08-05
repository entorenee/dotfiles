# `homeManagerUser` is `null` for a NixOS host with no home-manager (the
# airgap/uptime Pis, for now — see the redesign doc §8 step 5 / open question
# 3), or a username to wire up `roles/home/cli.nix` the same way the
# Darwin/home hosts wire `roles/home/gui.nix`: same `_module.args`, same
# `worktrunk.homeModules.default` import. `my.dotfiles.mutable = false`
# here (not per-host) so any future Pi added this way is immutable by
# default too, not just `hub` — see §6.1.
{
  nixpkgs,
  home-manager,
  lib,
  nixos-hardware,
  yubikey-guide,
  baseOverlays,
  mkHomeManagerArgs,
  worktrunk,
}: system: module: homeManagerUser:
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
            imports = [../roles/home/cli.nix worktrunk.homeModules.default];
            my.dotfiles.mutable = false;
            _module.args = mkHomeManagerArgs system homeManagerUser;
          };
        }
      ];
  }
