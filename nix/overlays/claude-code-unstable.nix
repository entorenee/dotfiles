# The repo pins nixpkgs to the 26.05 stable release, but claude-code ships
# far faster than a 6-month NixOS release cycle — freezing it at whatever
# 26.05 happened to carry would leave it materially stale. This applies a
# unstable escape hatch, so it's pulled from nixpkgs-unstable instead
# of the pinned channel.
#
# Applied universally (see flake.nix's `baseOverlays`), not per-host — every
# current and planned host imports `programs.claude-code` via
# roles/home/cli.nix.
{nixpkgs-unstable}: final: _prev: {
  claude-code =
    (import nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
    })
    .claude-code;
}
