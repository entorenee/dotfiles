{pkgs, ...}: {
  # The personal role, GUI-desktop add-on. Split out of personal.nix so a
  # headless personal host can take the portable base without pulling these in.
  imports = [
    ../../modules/home/keepassxc
    ../../modules/home/orca-slicer
  ];

  home.packages = with pkgs; [
    go
    hugo
  ];
}
