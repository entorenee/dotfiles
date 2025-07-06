{
  pkgs,
  ...
}:
{
  ## TODO: determine if this should be moved back to Homebrew for global application install
  home.packages =
    with pkgs;
    [
      karabiner-elements
    ];
  xdg.configFile."karabiner".source = ./config;
}
