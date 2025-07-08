{ ... }:
{
  homebrew.brews = [
    "nvm"
  ];

  home-manager.users."skyler.lemay" = { ... }: {
    xdg.configFile."nvm".source = ./config;
  };
}
