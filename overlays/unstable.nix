# Exposes nixpkgs-unstable as `pkgs.unstable`, so a host-scoped overlay or a
# module can take a fast-moving package from it without importing unstable a
# second time. claude-code ships far faster than the 6-month NixOS release
# cycle, so it is swapped in wholesale.
{nixpkgs-unstable}: final: _prev: let
  unstable = import nixpkgs-unstable {
    # Not `inherit (final) system`: nixpkgs demoted `pkgs.system` to a
    # warnAlias in pkgs/top-level/aliases.nix, so reading it prints an
    # evaluation warning on every build. Same string, no warning.
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in {
  inherit unstable;
  inherit (unstable) claude-code;
}
