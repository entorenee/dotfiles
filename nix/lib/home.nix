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
