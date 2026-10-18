{lib, ...}: {
  # The tunnel sink comes from modules/home/pipewire-zeroconf, and only exists
  # on the home LAN while LibreELEC's PulseAudio is up. mkAfter keeps the
  # local output first.
  services.mpd.extraConfig = lib.mkAfter ''
    audio_output {
      type "pipewire"
      name "LibreELEC"
      target "tunnel.LibreELEC.local.alsa_output.0.hdmi-stereo"
      # Only applies without a state file; after that MPD restores toggles.
      enabled "no"
    }
  '';
}
