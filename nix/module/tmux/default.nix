{ 
  pkgs,
  lib,
  ...
}:
let
  mkOrder = lib.mkOrder;
in
{
  # TODO: Figure out fonts getting exposed correctly
  programs = {
    tmux = {
      enable = true;
      shell = "/bin/zsh";
      plugins = with pkgs; [
        tmuxPlugins.sensible
        tmuxPlugins.vim-tmux-navigator
        {
          plugin = tmuxPlugins.tokyo-night-tmux;
          extraConfig = ''
            set -g @theme_variation 'night'
            set -g @theme_plugins 'datetime,weather,battery'
            set -g @theme_plugin_weather_location 'Portland, Oregon'
            set -g @theme_plugin_datetime_format '%Y-%m-%d %H:%M'
            # Show temp in metric, condition, and moon phase
            set -g @theme_plugin_weather_format '%t+%C+%m&m'
          '';
        }
      ];
    };
  };
  xdg.configFile."tmux/tmux.conf".text = mkOrder 600 (builtins.readFile ./tmux.conf);
}
