{config, ...}: let
  worktrunkConfigPath = "${config.home.homeDirectory}/dotfiles/nix/module/worktrunk/config";
in {
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

  xdg.configFile."worktrunk".source = config.lib.file.mkOutOfStoreSymlink worktrunkConfigPath;
}
