{
  lib,
  pkgs,
  private-assets ? null,
  ...
}: let
  # Check if private assets are available and contain fonts
  hasPrivateFonts = private-assets != null && builtins.pathExists "${private-assets}/fonts";

  # Create derivation to copy private fonts if available
  privateFonts =
    if hasPrivateFonts
    then
      pkgs.runCommand "private-fonts" {} ''
        mkdir -p $out/share/fonts
        cp -r ${private-assets}/fonts/* $out/share/fonts/
      ''
    else null;
in {
  fonts.fontconfig.enable = true;

  home.packages = with pkgs;
    [
      nerd-fonts.sauce-code-pro
    ]
    ++ lib.optionals hasPrivateFonts [
      privateFonts
    ];
}
