# `user` is a path into ./users — persona is selected by importing a
# directory, not by threading a string down to every module that cares.
# `extraHomeImports` lets a host opt into persona pieces that aren't part
# of that persona's portable base (e.g. the personal desktop-only add-ons
# in users/personal/desktop.nix) without forcing them on every host that
# imports the persona — see docs/local/plans/nix-architecture-redesign.md §4c.
# `overlays` is the same idea applied to nix/overlays/: a list of overlay
# functions this specific host wants (see §6.3), not a set applied globally.
{
  darwin,
  home-manager,
  home-manager-config,
  worktrunk,
  baseOverlays,
  mkHomeManagerArgs,
}: let
  mkDarwinConfig = username: user: system: extraHomeImports: overlays:
    import ../system/darwin.nix {
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
in {
  inherit mkDarwinConfig mkDarwinHost;
}
