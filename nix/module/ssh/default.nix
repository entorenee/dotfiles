{ username, profile, ... }:
let
  pubYubikeySsh = {
    personal = ./public-ssh-keys/personal.pub;
    ## work = ./public-ssh-keys/work.pub;
  };
  pubSshPath = pubYubikeySsh.${profile};
in
{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      github = {
        host = "github.com";
        identityFile = "/Users/${username}/.ssh/id_rsa_yubikey.pub";
        identitiesOnly = true;
      };
    };
  };
  home.file.".ssh/id_rsa_yubikey.pub".source = pubSshPath;
}
