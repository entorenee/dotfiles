{pkgs, ...}: {
  # Personal identity, GUI-desktop add-on. Split out of home.nix so a headless
  # personal Pi can import the portable base without pulling these in; hosts
  # that want this opt in via `extraHomeImports` — see
  # docs/local/plans/nix-architecture-redesign.md §4c.
  imports = [
    ../../modules/home/keepassxc
    ../../modules/home/orca-slicer
  ];

  home.packages = with pkgs; [
    go
    hugo
  ];
}
