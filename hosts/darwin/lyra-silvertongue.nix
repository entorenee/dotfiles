{
  username = "skyler.lemay";
  system = "aarch64-darwin";
  homeImports = [
    ../../roles/home/gui.nix
    ../../roles/home/personal.nix
    ../../roles/home/personal-desktop.nix
  ];
  darwinImports = [
    ../../roles/darwin/personal.nix
    # Must equal this host's darwinConfigurations attribute name — see the
    # "Pin every Darwin host's hostname" section of CLAUDE.md. Inline rather
    # than in roles/darwin/personal.nix: the name is this machine's, not the
    # identity's, so a second personal Mac must not inherit it.
    {networking.hostName = "lyra-silvertongue";}
  ];
}
