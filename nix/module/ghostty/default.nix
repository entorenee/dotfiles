{ username, ... }:
{
  homebrew.casks = [
    "ghostty"
  ];

  home-manager.users."${username}" = { ... }: {
    xdg.configFile."ghostty".source = ./config;
  };
}
