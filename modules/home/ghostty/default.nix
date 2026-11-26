{config, ...}: {
  xdg.configFile."ghostty".source = config.lib.dotfiles.link ./config;
}
