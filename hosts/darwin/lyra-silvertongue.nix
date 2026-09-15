{
  username = "skyler.lemay";
  system = "aarch64-darwin";
  homeImports = [
    ../../roles/home/gui.nix
    ../../roles/home/personal.nix
    ../../roles/home/personal-desktop.nix
    # Inline rather than a host file: this machine has no directory of its own,
    # matching the darwinImports precedent below.
    ({config, ...}: {
      age.identityPaths = ["${config.home.homeDirectory}/.config/age/keys.txt"];

      age.secrets.friction-deploy = {
        file = ../../secrets/friction-deploy-lyra-silvertongue.age;
        path = "${config.home.homeDirectory}/.ssh/id_ed25519_friction";
        mode = "0400";
      };
    })
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
