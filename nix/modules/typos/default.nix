{
  config,
  pkgs,
  ...
}: let
  typosPath = "${config.home.homeDirectory}/dotfiles/nix/modules/typos/config/";
in {
  home.packages = with pkgs; [
    typos
    typos-lsp
  ];

  xdg.configFile."typos".source = config.lib.file.mkOutOfStoreSymlink typosPath;
}
