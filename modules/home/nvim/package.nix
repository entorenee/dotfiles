{pkgs, ...}: {
  # The editor binary and nothing else — no plugin config, so it starts with
  # stock defaults and never reaches the network. Split from ./default.nix so
  # roles/home/minimal.nix can give a constrained or airgapped host a working
  # editor: the LazyVim config deployed there bootstraps its plugins from GitHub
  # on first launch, which airgapped *hangs* rather than merely being useless.
  home.packages = [pkgs.neovim];
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    MANPAGER = "nvim -c 'Man!' -o -";
  };
}
