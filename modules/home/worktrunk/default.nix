{...}: {
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

  # ~/.config/worktrunk/config.toml is the only path worktrunk reads — it has
  # no system/XDG_CONFIG_DIRS layer.
  #
  # A read-only store symlink is safe because worktrunk keeps machine-local
  # state in <repo>/.git/wt/, not in config.toml, so nothing writes this file.
  # The tradeoff: user-invoked `wt config` writes (approvals, aliases) do not
  # persist and must be declared in ./config/config.toml instead.
  xdg.configFile."worktrunk/config.toml".source = ./config/config.toml;
}
