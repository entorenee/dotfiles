{ 
  pkgs,
  lib,
  ...
}:
let
  mkOrder = lib.mkOrder;
  tmux-tokyo-night = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-tokyo-night";
    version = "unstable-2026-02-28";
    src = pkgs.fetchFromGitHub {
      owner = "fabioluciano";
      repo = "tmux-tokyo-night";
      rev = "1976b4bfa99ed6811f8752ab356df47a0c709d1e";
      sha256 = "09p21hpvgd3g0i8cqni35f6zdy5agl9vlf4j1379bhddjn1b505v";
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
