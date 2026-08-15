{pkgs, ...}: {
  # The binaries conform.nvim shells out to on save. Declared here rather than
  # left to mason-tool-installer, which fetches them per-machine outside Nix —
  # so their versions drift between hosts, and neither the pre-commit hook nor
  # CI can rely on them existing.
  #
  # modules/home/yamlfmt is separate only because it also deploys a config file;
  # which tier both belong to is decided in roles/home/base.nix.
  home.packages = with pkgs; [
    alejandra # nix
    prettier # markdown, json, css, html, js/ts
    shfmt # sh, bash, zsh
    stylua # lua
    taplo # toml
  ];
}
