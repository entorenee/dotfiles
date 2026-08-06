{pkgs, ...}: {
  # The editor binary and nothing else — no plugin config, so it starts with
  # stock defaults and never reaches the network.
  #
  # Split from ./default.nix so roles/home/minimal.nix can give a constrained or
  # airgapped host a working editor. The LazyVim config deployed by default.nix
  # bootstraps its plugins from GitHub on first launch, which on an airgapped
  # box hangs rather than merely being useless — that is why the split runs
  # along package-vs-config rather than one module gated by an option.
  home.packages = [pkgs.neovim];
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    MANPAGER = "nvim -c 'Man!' -o -";
  };
}
