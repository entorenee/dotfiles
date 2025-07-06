{ ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.zsh.initContent = ''
    vlist () {
      nvim -p $(rg -l "$1")
    }
  '';

  xdg.configFile."nvim".source = ./config;
}
