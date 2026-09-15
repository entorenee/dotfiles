# Host file shape: username, system triple, and the ordered module lists it
# composes itself from. `homeImports`, `darwinImports` and `overlays` are all
# passed through verbatim — nothing is spliced onto them here.
{
  agenix,
  darwin,
  home-manager,
  worktrunk,
  baseOverlays,
  mkHomeManagerArgs,
}: let
  mkDarwinConfig = username: system: homeImports: darwinImports: overlays:
    import ../system/darwin.nix {
      inherit agenix darwin home-manager username worktrunk homeImports darwinImports;
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
