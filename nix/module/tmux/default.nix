{ 
  pkgs,
  lib,
  ...
}:
let
  mkOrder = lib.mkOrder;
  tmux-tokyo-night = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-tokyo-night";
    version = "unstable-2025-07-27";
    src = pkgs.fetchFromGitHub {
      owner = "fabioluciano";
      repo = "tmux-tokyo-night";
      rev = "97cdce3e785f8a6cc1c569b87cd3020fdad7e637";
      sha256 = "03ifa97qcgjv7fapa2yfqgbrys1rlf5xzp1viqzvrid6fnxdnc2s";
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
