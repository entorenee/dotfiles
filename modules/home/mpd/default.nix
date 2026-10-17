{config, ...}: {
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

  programs.rmpc.enable = true;

  # Tell MPD to rescan after beets changes the library.
  programs.beets.settings.plugins = ["mpdupdate"];
}
