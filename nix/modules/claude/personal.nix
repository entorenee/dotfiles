{ lib, profile, ... }:
lib.mkIf (profile == "personal") {
  programs.claude-code = {
    settings = {
      enabledPlugins = {
        "gopls-lsp@claude-plugins-official" = true;
      };
      sandbox.filesystem = {
        allowRead = ["~/dotfiles" "~/.config/gh" "/nix/store" "/tmp" "/private/tmp"];
        allowWrite = ["~/dotfiles" "/tmp" "/private/tmp"];
      };
    };
  };
}
