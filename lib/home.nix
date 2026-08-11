{
  nixpkgs,
  home-manager,
  baseOverlays,
  mkHomeManagerArgs,
  worktrunk,
}: let
  mkHomeManagerConfig = username: system: homeImports: overlays: let
    pkgs = import nixpkgs {
      inherit system;
      overlays = baseOverlays ++ overlays;
      config.allowUnfree = true;
    };
  in
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {inherit worktrunk;};
      modules =
        homeImports
        ++ [
          worktrunk.homeModules.default
          {
            home.username = username;
            home.homeDirectory = "/home/${username}";
            _module.args = mkHomeManagerArgs system username;

            # Set here, not in a tier role: this is the only entry point where
            # it is structurally true, since a standalone home-manager host is
            # by construction running on a distro that does not manage it. The
            # NixOS and Darwin paths must never get it, and a role shared with
            # them cannot tell the difference.
            targets.genericLinux.enable = true;
          }
        ];
    };

  mkHomeHost = path: let
    host = import path;
  in
    mkHomeManagerConfig host.username host.system host.homeImports (host.overlays or []);
in {
  inherit mkHomeManagerConfig mkHomeHost;
}
