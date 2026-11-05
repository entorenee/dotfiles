{...}: {
  # Lets the NAS MPD play through this machine's speakers as a second pulse
  # output. pipewire-pulse has no IP ACL and ignores cookies, so ufw is the only
  # thing limiting who can connect: allow 4713 from the NAS alone. The drop-in
  # replaces the whole server.address list, hence restating unix:native.
  xdg.configFile."pipewire/pipewire-pulse.conf.d/tcp.conf".text = ''
    pulse.properties = {
      server.address = [ "unix:native" "tcp:4713" ]
    }
  '';
}
