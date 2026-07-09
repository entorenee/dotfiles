{pkgs, ...}: {
  programs.worktrunk = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh.initContent = ''
    # Inside tmux, worktrunk's post-switch hook handles window navigation
    # so disable the shell cd to avoid changing directory in the current pane
    if [ -n "$TMUX" ]; then
      export WORKTRUNK_SWITCH__CD=false
    fi
  '';

  # Deploy worktrunk's declarative settings as its read-only SYSTEM config
  # (profile etc/xdg), NOT the writable user config. worktrunk owns
  # ~/.config/worktrunk/config.toml and writes machine-local state there
  # ([projects], prompt flags, a .lock); the old mkOutOfStoreSymlink pointed a
  # git-tracked file at that path, so every worktrunk write dirtied the repo.
  home.packages = [
    (pkgs.writeTextDir "etc/xdg/worktrunk/config.toml"
      (builtins.readFile ./config/config.toml))
  ];
}
