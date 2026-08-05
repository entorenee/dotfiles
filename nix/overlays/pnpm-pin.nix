# Pin pnpm to the EXACT version fw_monorepo's package.json declares in its
# `packageManager` field (pnpm@10.33.0). pnpm's version manager compares the
# running binary against that pin; on any mismatch it re-downloads AND
# signature-verifies the pinned build from the npm registry on every
# command. That verification fetch fails inside Claude Code's network
# sandbox and hard-aborts with "npm registry signature could not be
# verified". Matching the version exactly means no switch, no fetch, no
# failure. A nearby 10.x (nixpkgs pnpm_10 is 10.34.5) does NOT work — the
# pin is exact.
#
# fw_monorepo is a work-only codebase — this overlay belongs only on the
# host that touches it, not on the personal machines.
#
# MAINTENANCE: bump both fields together whenever fw_monorepo changes its
# packageManager pin. Get the hash with:
#   nix store prefetch-file https://registry.npmjs.org/pnpm/-/pnpm-<version>.tgz
_final: prev: {
  pnpm = prev.pnpm_10.override {
    version = "10.33.0";
    hash = "sha256-v8wby60nmxOlFsRGp1s8WLaQS0XVehlRQRAV5Qt1GoA=";
  };
}
