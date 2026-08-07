{pkgs, ...}: {
  # The personal role, GUI-desktop add-on. Split out of personal.nix so a
  # headless personal Pi can take the portable base without pulling these in;
  # hosts that want it name this file in their own `homeImports` list.
  imports = [
    ../../modules/home/keepassxc
    ../../modules/home/orca-slicer
  ];

  home.packages = with pkgs; [
    go
    hugo
  ];
}
