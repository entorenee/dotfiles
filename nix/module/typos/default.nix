{
  config,
  pkgs,
  ...
}: let
  typosPath = "${config.home.homeDirectory}/dotfiles/nix/module/typos/config/";
in {
  home.packages = with pkgs; [
    typos
    typos-lsp
  ];

  xdg.configFile."typos".source = config.lib.file.mkOutOfStoreSymlink typosPath;
}
