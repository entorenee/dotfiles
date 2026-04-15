{ lib, profile, ... }:
lib.mkIf (profile == "personal") {
  programs.claude-code = {
    settings = {
      sandbox.permissions = {
        read.allow = ["~/dotfiles"];
        write.allow = ["~/dotfiles"];
      };
    };
  };
}
