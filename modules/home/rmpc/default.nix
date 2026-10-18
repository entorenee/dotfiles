{pkgs, ...}: {
  home.packages = with pkgs; [
    ueberzugpp
  ];

  programs.rmpc = {
    enable = true;
    # Auto picks ueberzugpp's Wayland output, which aborts on compositors it
    # has no config for (COSMIC). X11 needs Alacritty under XWayland.
    config = ''
      #![enable(implicit_some)]
      #![enable(unwrap_newtypes)]
      #![enable(unwrap_variant_newtypes)]
      (
          theme: "tokyonight_night",
          album_art: (
              method: UeberzugX11,
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
