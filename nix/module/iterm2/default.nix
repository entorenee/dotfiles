{ ... }:
{
  homebrew.casks = [
    "iterm2"
  ];

  home-manager.users."skyler.lemay" = { ... }: {
    xdg.configFile."iterm2".source = ./config;
  };
}
