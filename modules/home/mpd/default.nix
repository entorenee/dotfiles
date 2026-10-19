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

  # Tell MPD to rescan after beets changes the library.
  programs.beets.settings.plugins = ["mpdupdate"];

  # Submits MPD plays to ListenBrainz, so they reach beets' lbimport.
  services.mpdscribble = {
    enable = true;
    endpoints.listenbrainz = {
      username = "autumntwighlight";
      passwordFile = config.age.secrets.listenbrainz-token.path;
    };
  };

  # The bare token: mpdscribble substitutes the whole file as the password, so
  # it can't share beets' YAML secret. Explicit path because the module
  # single-quotes it, and the default holds a literal ${XDG_RUNTIME_DIR}.
  age.secrets.listenbrainz-token = {
    file = ../../../secrets/listenbrainz-token.age;
    path = "${config.xdg.configHome}/mpdscribble/listenbrainz-token";
    mode = "0400";
  };

  # ExecStartPre reads the token, so it has to be decrypted first.
  systemd.user.services.mpdscribble.Unit.After = ["agenix.service"];
}
