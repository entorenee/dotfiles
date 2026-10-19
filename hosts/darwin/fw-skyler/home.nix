{
  config,
  lib,
  pkgs,
  ...
}: let
  personalYubikeyIdentity = "${config.home.homeDirectory}/.ssh/id_rsa_yubikey_personal.pub";
  workYubikeyIdentity = "${config.home.homeDirectory}/.ssh/id_rsa_yubikey_work.pub";
  ghDashConfig = "${config.home.homeDirectory}/dotfiles/hosts/darwin/fw-skyler/gh-dash.yml";
in {
  imports = [
    ./claude.nix
  ];

  home.packages = with pkgs; [
    cocoapods
    doctl
    mkcert
    ngrok
    ruby
    temurin-bin-17
  ];

  programs.mise.globalConfig.tools."npm:@posthog/cli" = "latest";

  # Replaces the module's `mkDefault` list rather than appending to it, so the
  # personal Yubikey has to be restated — it authenticates the dotfiles checkout
  # on every machine.
  programs.ssh.settings."github.com".IdentityFile = [
    personalYubikeyIdentity
    workYubikeyIdentity
  ];

  home.file.".ssh/id_rsa_yubikey_work.pub".source = ./id_rsa_yubikey_work.pub;

  age.identityPaths = ["${config.home.homeDirectory}/.config/age/keys.txt"];

  age.secrets.friction-deploy = {
    file = ../../../secrets/friction-deploy-fw-skyler.age;
    path = "${config.home.homeDirectory}/.ssh/id_ed25519_friction";
    mode = "0400";
  };

  # Server instance MPD; no media lives on this machine.
  age.secrets.mpd-password = {
    file = ../../../secrets/mpd-password.age;
    mode = "0400";
  };

  # MPD_HOST outranks the config's address, and is set for rmpc alone so the
  # password stays out of the shell environment. No port: rmpc appends
  # MPD_PORT or 6600 to the host, so "host:6600" would become "host:6600:6600".
  programs.rmpc.package = pkgs.writeShellApplication {
    name = "rmpc";
    runtimeEnv.MPD_PASSWORD_FILE = config.age.secrets.mpd-password.path;
    text = ''
      MPD_HOST="$(<"$MPD_PASSWORD_FILE")@192.168.1.168" exec ${lib.getExe pkgs.rmpc} "$@"
    '';
  };

  xdg.configFile."gh-dash/config.yml".source =
    lib.mkForce (config.lib.file.mkOutOfStoreSymlink ghDashConfig);
}
