{
  config,
  pkgs,
  ...
}: {
  services.mpd = {
    enable = true;
    # ~/Music, not ~/Music/artists, so playlist entries read artists/…, the
    # form beets' smartplaylist and beets-random write.
    musicDirectory = "${config.home.homeDirectory}/Music";
    # The folder beets writes to and rockbox-playlists syncs, so rmpc's
    # Playlists tab edits the same files the card gets. MPD ignores .m3u8 here.
    playlistDirectory = "${config.home.homeDirectory}/Music/playlists";
    network.listenAddress = "127.0.0.1";
    extraConfig = ''
      audio_output {
        type "pipewire"
        name "PipeWire"
      }
    '';
  };

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
          album_art: (
              method: UeberzugX11,
          ),
      )
    '';
  };

  # Tell MPD to rescan after beets changes the library.
  programs.beets.settings.plugins = ["mpdupdate"];
}
