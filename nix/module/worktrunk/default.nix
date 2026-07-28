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

  # Deploy worktrunk's declarative settings to the ONE path worktrunk reads:
  # the user config at ~/.config/worktrunk/config.toml. worktrunk (36ba57b)
  # has no system/XDG_CONFIG_DIRS layer, so the previous etc/xdg deployment was
  # never picked up (and home.packages doesn't link an etc/ tree anyway).
  #
  # A read-only store symlink is safe here because worktrunk keeps its
  # machine-local state in <repo>/.git/wt/ (branch markers, caches, logs, prev
  # branch), NOT in config.toml — so nothing tries to write this file and the
  # old repo-dirtying problem doesn't apply. User-invoked `wt config` writes
  # (approvals, aliases) must instead be declared in ./config/config.toml.
  xdg.configFile."worktrunk/config.toml".source = ./config/config.toml;
}
