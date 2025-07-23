{ 
  pkgs,
  lib,
  ...
}:
let
  mkOrder = lib.mkOrder;
  tmux-tokyo-night = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-tokyo-night";
    version = "unstable-2025-07-13";
    src = pkgs.fetchFromGitHub {
      owner = "fabioluciano";
      repo = "tmux-tokyo-night";
      rev = "main";
      sha256 = "sha256-p0CbzwG0i6UeIiY2pEx4TTn2bukZmJS008yR34N9APU=";
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
            set -g @theme_plugin_weather_location 'Portland, Oregon'
            # Show temp in metric, condition, and moon phase
            set -g @theme_plugin_weather_format '%t+%C+%m&m'
          '';
        }
      ];
    };
  };
  xdg.configFile."tmux/tmux.conf".text = mkOrder 600 (builtins.readFile ./tmux.conf);
}
