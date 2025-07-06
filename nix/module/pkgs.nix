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
      git-lfs
      git-up
      # gnupg
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
      # spaceship-prompt
      tmuxinator
      tree
      # vlc
      vlc-bin-universal
      wget
      yubikey-manager
      zoom-us
    ];
}
