{
  lib,
  pkgs,
  ...
}: {
  # Shell ergonomics only — file viewing, searching, JSON, process monitoring.
  # Everything here is a small, local, single-shot CLI tool: no language
  # runtimes, no daemons, no network clients, nothing that assumes a remote or
  # a dotfiles checkout. This is what makes the list safe on an airgapped or
  # resource-constrained host, so keep that bar when adding to it.
  #
  # Dev tooling and language runtimes live in cli-pkgs.nix (imported from
  # roles/home/cli.nix); Linux-desktop packages live in linux-gui-pkgs.nix
  # (imported from roles/home/gui.nix). Identity and host package sets live in
  # the relevant roles/ or hosts/ file — `home.packages` is a `listOf package`,
  # so all of these definitions concatenate.
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
