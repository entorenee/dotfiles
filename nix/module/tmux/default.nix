{ 
  pkgs,
  lib,
  ...
}:
let
  mkOrder = lib.mkOrder;
  tmux-tokyo-night = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-tokyo-night";
    version = "unstable-2025-12-20";
    src = pkgs.fetchFromGitHub {
      owner = "fabioluciano";
      repo = "tmux-tokyo-night";
      rev = "60b99a078030331e0685766e5d45e49d84b2b823";
      sha256 = "1z8hrbkmhfc2gfgac8djr3d3524h589h77y6866m4pdnjk45406y";
    };
    rtpFilePath = "tmux-tokyo-night.tmux";
  };
in
{
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
          plugin = tmux-tokyo-night;
          extraConfig = ''
            set -g @theme_variation 'night'
            set -g @theme_plugins 'datetime,weather,battery'
            set -g @theme_plugin_datetime_format '%F %H:%M'
            set -g @theme_plugin_weather_location 'Portland, Oregon'
            # Show temp in metric, condition, and moon phase
            set -g @theme_plugin_weather_format '%t+%C+%m&m'
            set -g @theme_active_pane_border_style '#9D7CD8'
          '';
        }
      ];
    };
  };
  xdg.configFile."tmux/tmux.conf".text = mkOrder 600 (builtins.readFile ./tmux.conf);
}
