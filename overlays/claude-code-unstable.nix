# claude-code ships far faster than the 6-month NixOS release cycle, so take it
# from nixpkgs-unstable rather than the repo's 26.05 pin.
#
# Universal, not per-host (see flake.nix's `baseOverlays`) — every host imports
# `programs.claude-code` via roles/home/cli.nix.
{nixpkgs-unstable}: final: _prev: {
  claude-code =
    (import nixpkgs-unstable {
      # Not `inherit (final) system`: nixpkgs demoted `pkgs.system` to a
      # warnAlias in pkgs/top-level/aliases.nix, so reading it prints an
      # evaluation warning on every build. Same string, no warning.
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    })
    .claude-code;
}
