{ ... }:
{
  homebrew.casks = [
    "karabiner-elements"
  ];

  home-manager.users."skyler.lemay" = { ... }: {
    xdg.configFile."karabiner".source = ./config;
  };
}
