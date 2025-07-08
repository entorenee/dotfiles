{ ... }:
{
  homebrew.casks = [
    "ghostty"
  ];

  home-manager.users."skyler.lemay" = { ... }: {
    xdg.configFile."ghostty".source = ./config;
  };
}
