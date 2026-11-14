{...}: {
  # Obsidian vault cataloguing owned music (vinyl, CD, digital). Nix owns only
  # `.obsidian/`; the notes, template and Collection.base are seeded once from
  # templates/obsidian/collection-vault/. Every `.obsidian/` file is a store
  # symlink, so Syncthing must ignore that folder: Android can't follow them.
  programs.obsidian = {
    enable = true;
    # Installed by linux-gui-pkgs.nix.
    package = null;
    vaults.collection = {
      target = "Music/collection";
      settings = {
        app = {
          newFileLocation = "folder";
          newFileFolderPath = "Releases";
          vimMode = true;
        };
        corePlugins = [
          "bases"
          "bookmarks"
          "command-palette"
          "file-explorer"
          "file-recovery"
          "global-search"
          "properties"
          "switcher"
          {
            name = "templates";
            settings.folder = "Templates";
          }
        ];
      };
    };
  };
}
