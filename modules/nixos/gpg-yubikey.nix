# Shared GPG + Yubikey smartcard support for NixOS hosts: pcscd (so gpg-agent
# can talk to the Yubikey over CCID) plus a curses pinentry, which works on
# console and over SSH alike.
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
