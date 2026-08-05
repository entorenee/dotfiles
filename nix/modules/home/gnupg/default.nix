{
  config,
  lib,
  pkgs,
  ...
}: let
  gnupgPath = "${config.home.homeDirectory}/dotfiles/nix/modules/home/gnupg/config";

  # Dynamically assemble agent conf
  baseAgentConf = builtins.readFile ./config/gpg-agent.base;
  # `my.gui` rather than `isLinux`: a headless host has no display for
  # pinentry-gnome3 to draw on and must fall back to the curses prompt.
  pinentryLine =
    if pkgs.stdenv.isDarwin
    then "pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac"
    else if config.my.gui
    then "pinentry-program ${pkgs.pinentry-gnome3}/bin/pinentry-gnome3"
    else "pinentry-program ${pkgs.pinentry-curses}/bin/pinentry-curses";
  gpgAgentConf = lib.concatStringsSep "\n" [baseAgentConf pinentryLine];
in {
  programs.gpg.publicKeys = [
    {
      source = ./public-keys/personal-pub.asc;
      trust = "ultimate";
    }
    {
      source = ./public-keys/freeworld-pub.asc;
      trust = "ultimate";
    }
  ];

  programs.zsh.initContent = ''
    export GPG_TTY=$(tty)
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
  '';

  home.file.".gnupg/gpg.conf".source = config.lib.file.mkOutOfStoreSymlink "${gnupgPath}/gpg.conf";
  home.file.".gnupg/scdaemon.conf".source = config.lib.file.mkOutOfStoreSymlink "${gnupgPath}/scdaemon.conf";
  home.file.".gnupg/gpg-agent.conf".text = gpgAgentConf;
}
