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
      # iterm2
      jq
      # karabiner-elements
      # nerd-fonts.sauce-code-pro
      # obsidian
      # pinentry-tty
      # pinentry_mac
      # postgresql
      # python313
      rectangle
      ripgrep
      tmuxinator
      tree
      # vlc
      vlc-bin-universal
      wget
      yubikey-manager
      zoom-us
    ];
}
