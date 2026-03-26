{
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
        # tmuxPlugins.sensible
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
          '';
        }
      ];
    };
  };
  xdg.configFile."tmux/tmux.conf".text = lib.mkOrder 600 (builtins.readFile ./tmux.conf);
}
