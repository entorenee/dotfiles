{pkgs, ...}: {
  home.packages = with pkgs; [
    typos
    typos-lsp
  ];

  xdg.configFile."typos".source = ./config;
}
