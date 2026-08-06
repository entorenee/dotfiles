{ config, ... }:
let
  nvimPath = "${config.home.homeDirectory}/dotfiles/nix/modules/home/nvim/config";
in
{
  # The configured editor: LazyVim config plus the shell helpers that assume it.
  # The bare binary lives in ./package.nix, which roles/home/minimal.nix imports
  # on its own for hosts that must not fetch plugins — see the note there.
  # Importing this module gets the package too; the module system dedupes by
  # path, so the two import sites do not conflict.
  imports = [ ./package.nix ];

  programs.zsh.initContent = ''
    vlist () {
      nvim -p $(rg -l "$1")
    }
  '';

  xdg.configFile."nvim".source =
    if config.my.dotfiles.mutable
    then config.lib.file.mkOutOfStoreSymlink nvimPath
    else ./config;
}
