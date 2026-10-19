{
  lib,
  pkgs,
  ...
}: let
  albumArtMethod =
    if pkgs.stdenv.isDarwin
    then "Kitty"
    else "UeberzugX11";
in {
  home.packages = lib.optionals pkgs.stdenv.isLinux [pkgs.ueberzugpp];

  programs.rmpc = {
    enable = true;
    config = ''
      #![enable(implicit_some)]
      #![enable(unwrap_newtypes)]
      #![enable(unwrap_variant_newtypes)]
      (
          theme: "tokyonight_night",
          album_art: (
              method: ${albumArtMethod},
          ),
          // The rmpc-docs catppuccin example's companion tabs, which give the queue an album art pane.
          tabs: [
              (
                  name: "Queue",
                  pane: Split(
                      direction: Horizontal,
                      panes: [(size: "60%", pane: Pane(Queue)), (size: "40%", pane: Pane(AlbumArt))],
                  ),
              ),
              (name: "Directories", pane: Pane(Directories)),
              (name: "Artists", pane: Pane(Artists)),
              (name: "Album Artists", pane: Pane(AlbumArtists)),
              (name: "Albums", pane: Pane(Albums)),
              (name: "Playlists", pane: Pane(Playlists)),
              (name: "Search", pane: Pane(Search)),
          ],
      )
    '';
  };

  # rmpc resolves `theme` to rmpc/themes/<name>.ron; the module has no theme option.
  xdg.configFile."rmpc/themes".source = ./themes;
}
