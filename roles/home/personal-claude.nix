{...}: {
  programs.claude-code = {
    settings = {
      enabledPlugins = {
        "gopls-lsp@claude-plugins-official" = true;
      };
      sandbox.filesystem = {
        allowRead = ["~/Music/collection" "~/dotfiles" "~/.config/gh" "/nix/store" "/tmp" "/private/tmp"];
        allowWrite = ["~/Music/collection" "~/dotfiles" "/tmp" "/private/tmp"];
      };
    };
  };
}
