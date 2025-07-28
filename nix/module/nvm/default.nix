{ config, ... }:
let
  nvmPath = "${config.home.homeDirectory}/dotfiles/nix/module/nvm/config";
in
{
  # TODO: previously my setup script made sure that LTS was installed
  # Determine if this will get ported over to the Nix setup
  # nvm install --lts
  # nvm alias default 'lts/*'

  xdg.configFile."nvm".source = config.lib.file.mkOutOfStoreSymlink nvmPath;
}
