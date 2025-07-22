{ username, ... }:
{
  homebrew.casks = [
    "karabiner-elements"
  ];

  home-manager.users."${username}" = { ... }: {
    xdg.configFile."karabiner".source = ./config;
  };
}
