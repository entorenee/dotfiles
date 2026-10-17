{config, ...}: {
  services.mpd = {
    enable = true;
    # ~/Music, not ~/Music/artists, so playlists/ sits inside it and the
    # ../artists/… entries in smartplaylist's output resolve.
    musicDirectory = "${config.home.homeDirectory}/Music";
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
