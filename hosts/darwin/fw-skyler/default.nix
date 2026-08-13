{
  username = "fw-skylerlemay";
  system = "aarch64-darwin";
  # Work has exactly one machine, so its role files live here on the host
  # rather than in roles/ — there is no second consumer to share them with.
  homeImports = [
    ../../../roles/home/gui.nix
    ../../../modules/home/mise
    ./home.nix
  ];
  darwinImports = [./darwin.nix];
  # fw_monorepo's pnpm pin is only relevant on the machine that checks it out.
  overlays = [(import ../../../overlays/pnpm-pin.nix)];
}
