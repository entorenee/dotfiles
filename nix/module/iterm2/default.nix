{ username, ... }:
{
  homebrew.casks = [
    "iterm2"
  ];

  home-manager.users."${username}" = { ... }: {
    xdg.configFile."iterm2".source = ./config;
  };
}
