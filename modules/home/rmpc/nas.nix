{
  config,
  lib,
  pkgs,
  ...
}: let
  # MPD_HOST outranks the config's address, and is set for this command alone
  # so the password stays out of the shell environment. No port: rmpc appends
  # MPD_PORT or 6600, so "host:6600" would become "host:6600:6600".
  wrapper = pkgs.writeShellApplication {
    name = "rmpc";
    runtimeEnv.MPD_PASSWORD_FILE = config.age.secrets.mpd-password.path;
    text = ''
      MPD_HOST="$(<"$MPD_PASSWORD_FILE")@192.168.1.168" exec ${lib.getExe pkgs.rmpc} "$@"
    '';
  };
in {
  # The Homelab MPD. Explicit path because runtimeEnv single-quotes it, and
  # agenix's default holds shell to expand (${XDG_RUNTIME_DIR} on Linux,
  # $(getconf …) on Darwin).
  age.secrets.mpd-password = {
    file = ../../../secrets/mpd-password.age;
    path = "${config.home.homeDirectory}/.config/mpd/password";
    mode = "0400";
  };

  # No host runs a local MPD, so plain `rmpc` means the NAS.
  programs.rmpc.package = wrapper;
}
