# Match fw_monorepo's `packageManager` pin EXACTLY. On any mismatch pnpm
# re-downloads and signature-verifies the pinned build from the npm registry on
# every command, which fails inside Claude Code's network sandbox. A nearby 10.x
# does not work, so nixpkgs' own `pnpm_10` cannot stand in for this override.
#
# Work-only codebase, so only hosts/darwin/fw-skyler names this overlay.
#
# MAINTENANCE: bump both fields together when fw_monorepo moves its pin, and
# update permittedInsecurePackages in hosts/darwin/fw-skyler/darwin.nix. Hash:
#   nix store prefetch-file https://registry.npmjs.org/pnpm/-/pnpm-<version>.tgz
_final: prev: {
  pnpm = prev.pnpm_10.override {
    version = "10.33.0";
    hash = "sha256-v8wby60nmxOlFsRGp1s8WLaQS0XVehlRQRAV5Qt1GoA=";
  };
}
