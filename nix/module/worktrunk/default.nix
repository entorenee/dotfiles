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

  # In-store symlink (not mkOutOfStoreSymlink) so the resulting
  # ~/.config/worktrunk/config.toml is read-only — prevents worktrunk
  # from rewriting it during interactive prompts.
  xdg.configFile."worktrunk/config.toml".source = ./config/config.toml;
}
