{
  pkgs,
  ...
}:
{
  programs.gpg = {
    enable = true;
    settings = {
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      cert-digest-algo = "SHA512";
      s2k-digest-algo = "SHA512";
      s2k-cipher-algo = "AES256";
      charset = "utf-8";
      no-comments = true;
      no-emit-version = true;
      no-greeting = true;
      keyid-format = "0xlong";
      list-options = "show-uid-validity";
      verify-options = "show-uid-validity";
      with-fingerprint = true;
      require-cross-certification = true;
      require-secmem = true;
      no-symkey-cache = true;
      armor = true;
      use-agent = true;
      throw-keyids = true;
    };
    scdaemonSettings = {
      disable-ccid = true;
    };
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
  services.gpg-agent = {
    enable = true;
    enableScDaemon = true;
    enableSshSupport = true;
    defaultCacheTtl = 60;
    maxCacheTtl = 120;
    pinentry = {
      package = pkgs.pinentry_mac;
    };
    extraConfig = ''
      ttyname $GPG_TTY
    '';
  };
  home.file.".gnupg/common.conf".source = ./common.conf;
}
