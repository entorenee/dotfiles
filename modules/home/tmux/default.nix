{
  config,
  tmux-powerkit,
  lib,
  pkgs,
  ...
}: {
  programs = {
    tmux = {
      enable = true;
      shell = "${pkgs.zsh}/bin/zsh";
      terminal = "xterm-256color";
      baseIndex = 1;
      clock24 = true;
      keyMode = "vi";
      mouse = true;
      plugins = with pkgs; [
        tmuxPlugins.vim-tmux-navigator
        {
          plugin = tmux-powerkit.packages.${pkgs.stdenv.hostPlatform.system}.default;
          extraConfig = ''
            set -g @powerkit_status_position "bottom"
            set -g @powerkit_theme "tokyo-night"
            set -g @powerkit_theme_variant "night"
            set -g @powerkit_plugins "datetime,weather,battery"
            set -g @powerkit_plugin_datetime_format "%F %H:%M"
            # set -g @powerkit_plugin_weather_location "Portland, Oregon"
            # Show temp in metric, condition, and moon phase
            set -g @powerkit_plugin_weather_units "m"
            # set -g @powerkit_plugin_weather_format "%t %C %m"
            set -g @powerkit_active_pane_border_style "#9D7CD8"
            # Keep the active window's full branch name, but shorten inactive
            # ones: drop the conventional-commit prefix (worktrunk sanitizes
            # feat/foo -> feat-foo), then cap at 13 chars with an ellipsis.
            set -g @powerkit_active_window_title "#W"
            set -g @powerkit_inactive_window_title "#{=/13/…:#{s/^(feat|fix|docs|chore|refactor|test|perf|ci)-//:#{window_name}}}"
          '';
        }
      ];
    };
  };
  # Substituted at build time rather than left as
  # ${MY_CLAUDE_ARTIFACTS_ROOT} for tmux to expand.
  xdg.configFile."tmux/tmux.conf".text = lib.mkOrder 600 (
    builtins.replaceStrings
    ["@artifactsRoot@"]
    [config.home.sessionVariables.MY_CLAUDE_ARTIFACTS_ROOT]
    (builtins.readFile ./tmux.conf)
  );
}
