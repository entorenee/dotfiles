{
  config,
  lib,
  pkgs,
  ...
}: let
  gnupgPath = "${config.home.homeDirectory}/dotfiles/nix/module/gnupg/config";

  # Dynamically assemble agent conf
  baseAgentConf = builtins.readFile ./config/gpg-agent.base;
  pinentryLine =
    if pkgs.stdenv.isLinux
    then "pinentry-program ${pkgs.pinentry-gnome3}/bin/pinentry-gnome3"
    else if pkgs.stdenv.isDarwin
    then "pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac"
    else "";
  gpgAgentConf = lib.concatStringsSep "\n" (
    [baseAgentConf]
    ++ (
      if pinentryLine != ""
      then [pinentryLine]
      else []
    )
  );
in {
  programs.gpg = {
    publicKeys = [
      {
        source = ./public-keys/personal-pub.asc;
        trust = "ultimate";
      }
      {
        source = ./public-keys/freeworld-pub.asc;
        trust = "ultimate";
      }
    ];
  };

  programs.zsh.initContent = ''
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
  '';

  home.file.".gnupg/gpg.conf".source = config.lib.file.mkOutOfStoreSymlink "${gnupgPath}/gpg.conf";
  home.file.".gnupg/scdaemon.conf".source = config.lib.file.mkOutOfStoreSymlink "${gnupgPath}/scdaemon.conf";
  home.file.".gnupg/gpg-agent.conf".text = gpgAgentConf;
}
