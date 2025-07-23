{
  lib,
  username,
  profile,
  ...
}:
let
  personalKeyPath = ./public-ssh-keys/id_rsa_yubikey_personal.pub;
  workKeyPath = ./public-ssh-keys/id_rsa_yubikey_work.pub;
  isWorkProfile = profile == "work";
in
{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      github = {
        host = "github.com";
        identityFile = [
          "/Users/${username}/.ssh/id_rsa_yubikey_personal.pub"
        ] ++ lib.optional isWorkProfile "/Users/${username}/.ssh/id_rsa_yubikey_work.pub";
        identitiesOnly = true;
      };
    };
  };

  # Always include personal key file, for dotfiles access
  home.file.".ssh/id_rsa_yubikey_personal.pub".source = personalKeyPath;

  # Conditionally copy work public key for work profile
  home.file.".ssh/id_rsa_yubikey_work.pub" = lib.mkIf isWorkProfile {
    source = workKeyPath;
  };
}
