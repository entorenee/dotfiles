{
  nixpkgs,
  home-manager,
  home-manager-config,
  baseOverlays,
  mkHomeManagerArgs,
  worktrunk,
}: let
  mkHomeManagerConfig = username: user: system: extraHomeImports: overlays: let
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
        [
          home-manager-config
          (user + "/home.nix")
        ]
        ++ extraHomeImports
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
    mkHomeManagerConfig host.username host.user host.system (host.extraHomeImports or []) (host.overlays or []);
in {
  inherit mkHomeManagerConfig mkHomeHost;
}
