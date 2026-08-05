{
  username = "fw-skylerlemay";
  user = ./.;
  system = "aarch64-darwin";
  # fw_monorepo's pnpm pin is only relevant on the machine that checks it out.
  overlays = [(import ../../../overlays/pnpm-pin.nix)];
}
