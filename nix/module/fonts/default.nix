{
  pkgs,
  ...
}:
{
  # TODO: Determine if there is a declarative way to handle private fonts
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    nerd-fonts.sauce-code-pro
  ];
}
