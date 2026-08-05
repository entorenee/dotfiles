{...}: {
  programs.lazygit = {
    enable = true;
  };

  xdg.configFile."lazygit".source = ./config;
}
