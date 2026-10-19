{...}: {
  # Turns PulseAudio sinks advertised over mDNS (the LibreELEC box) into local
  # tunnel sinks. Uses the system PipeWire and avahi; nothing is installed.
  # A tunnel that drops is not retried until the remote re-announces itself.
  xdg.configFile."pipewire/pipewire.conf.d/zeroconf-discover.conf".text = ''
    context.modules = [
      { name = libpipewire-module-zeroconf-discover }
    ]
  '';
}
