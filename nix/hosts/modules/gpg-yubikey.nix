# Shared GPG + Yubikey smartcard support for NixOS hosts. Provides pcscd (so
# gpg-agent can talk to the Yubikey over CCID), a system-level gpg-agent with
# a curses pinentry (works both on console and over SSH), and the packages
# needed to manage a Yubikey and sign with it.
{pkgs, ...}: {
  services.pcscd.enable = true;

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  environment.systemPackages = with pkgs; [
    gnupg
    pinentry-curses
    yubikey-manager
    yubikey-personalization
  ];
}
