{ 
  pkgs,
  lib,
  ...
}:
let
  mkOrder = lib.mkOrder;
  tmux-tokyo-night = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-tokyo-night";
    version = "unstable-2025-12-01";
    src = pkgs.fetchFromGitHub {
      owner = "fabioluciano";
      repo = "tmux-tokyo-night";
      rev = "17ccc64c2e133817da88ba9b9473479f7c74fd51";
      sha256 = "0z9xxm8cc66gsyqdfhn9c7l9ma2y77w3dnpai1zjm33zpv4mnqir";
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
