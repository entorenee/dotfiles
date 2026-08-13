{
  lib,
  pkgs,
  ...
}: {
  # Shell ergonomics only — small, local, single-shot CLI tools. No language
  # runtimes, no daemons, no network clients, nothing assuming a remote or a
  # dotfiles checkout. That bar is what keeps the list safe on an airgapped or
  # resource-constrained host; hold it when adding. Dev tooling goes in
  # cli-pkgs.nix, Linux-desktop packages in linux-gui-pkgs.nix.
  home.packages = with pkgs;
    [
      bat
      fd
      glow
      gum
      htop
      jq
      ripgrep
      tree
    ]
    # z-lua is a shell directory jumper — it belongs with the shell, not with
    # the dev tooling. macOS gets `z` from Homebrew instead (see the zsh
    # module's profileExtra).
    ++ lib.optionals pkgs.stdenv.isLinux [pkgs.z-lua];
}
