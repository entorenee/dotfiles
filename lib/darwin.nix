# A host file states which machine this is: username, system triple, and the
# ordered module lists it composes itself from. `homeImports` and
# `darwinImports` each carry a role stack plus whatever else that machine
# wants — there is no separate persona path or `extraHomeImports`, and no
# filename contract for the flake to splice onto. `overlays` is the same idea
# applied to overlays/: a list of overlay functions this specific host
# wants (see §6.3), not a set applied globally.
{
  darwin,
  home-manager,
  worktrunk,
  baseOverlays,
  mkHomeManagerArgs,
}: let
  mkDarwinConfig = username: system: homeImports: darwinImports: overlays:
    import ../system/darwin.nix {
      inherit darwin home-manager username worktrunk homeImports darwinImports;
      overlays = baseOverlays ++ overlays;
      homeManagerArgs = mkHomeManagerArgs system username;
    }
    system;

  mkDarwinHost = path: let
    host = import path;
  in
    mkDarwinConfig host.username host.system host.homeImports (host.darwinImports or []) (host.overlays or []);
in {
  inherit mkDarwinConfig mkDarwinHost;
}
