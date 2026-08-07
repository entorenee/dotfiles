# A NixOS host file states the same kind of attrset the Darwin and standalone
# home hosts do: `{system, nixosImports, username ? null, homeImports ? []}`.
# `nixosImports` carries the machine's own configuration plus whichever
# roles/nixos/ and modules/nixos/ files it wants; `homeImports` is the home
# side, named by the host rather than hardcoded here — the same reason
# flake.nix no longer hardcodes a role for the Macs.
#
# A host omits `username` when it wants no home-manager at all (airgap, and
# uptime until its own commit lands). `my.dotfiles.mutable = false` is set here
# rather than per-host so any future Pi is immutable by default — see §6.1.
{
  nixpkgs,
  home-manager,
  lib,
  nixos-hardware,
  yubikey-guide,
  baseOverlays,
  mkHomeManagerArgs,
  worktrunk,
}: let
  mkNixosConfig = system: nixosImports: username: homeImports:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit nixos-hardware yubikey-guide;};
      modules =
        nixosImports
        ++ lib.optionals (username != null) [
          home-manager.nixosModules.home-manager
          ({pkgs, ...}: {
            # Deliberately inside this branch: a host with no home-manager gets
            # no overlays and no allowUnfree, which is what airgap and uptime
            # have always evaluated to. Hoisting these out would silently
            # change their closures.
            #
            # `useGlobalPkgs = true` means they must be set at the NixOS system
            # level, same as system/darwin.nix's "System settings" block — a
            # home-manager module can't set either once there's no separate
            # pkgs left for it to configure (§6.3).
            nixpkgs.overlays = baseOverlays;
            nixpkgs.config.allowUnfree = true;

            # Every home role imports modules/home/zsh, so a Pi with
            # home-manager wants zsh as its login shell. Under bash the
            # gpg-agent SSH_AUTH_SOCK export never runs — home-manager injects
            # it into zsh's envExtra, not into hm-session-vars.sh.
            programs.zsh.enable = true;
            users.users.${username}.shell = pkgs.zsh;

            # /etc/zshrc's compinit duplicates oh-my-zsh's.
            programs.zsh.enableGlobalCompInit = false;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.${username} = {
              imports = homeImports ++ [worktrunk.homeModules.default];
              my.dotfiles.mutable = false;
              _module.args = mkHomeManagerArgs system username;
            };
          })
        ];
    };

  mkNixosHost = path: let
    host = import path;
  in
    mkNixosConfig host.system host.nixosImports (host.username or null) (host.homeImports or []);
in {
  inherit mkNixosConfig mkNixosHost;
}
