{
  pkgs,
  ...
}:
{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
  home.packages =
    with pkgs;
    [
      bash # tmux theme needs a more recent version of bash
      bat
      cargo # Nix LSP dependency
      git-lfs
      git-up
      htop
      jq
      # postgresql
      # python313
      ripgrep
      tmuxinator
      tree
      wget
      yubikey-manager
    ];
}
