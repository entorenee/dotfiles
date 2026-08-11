# Host file shape: `{system, nixosImports, username ? null, homeImports ? []}`.
# A host omits `username` when it wants no home-manager at all (airgap).
#
# `my.dotfiles.mutable = false` is set here rather than per-host so every Pi
# deploys config as a store copy, not an out-of-store symlink: a Pi's
# ~/dotfiles checkout may not exist when home-manager activates.
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
            # no overlays and no allowUnfree, which is what airgap has always
            # evaluated to. Hoisting these out would silently change its closure.
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
