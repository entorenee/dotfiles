{
  config,
  pkgs,
  ...
}: let
  vault = config.programs.obsidian.vaults.collection;

  # See scripts/collection-notes.sh; run after each import.
  collectionNotes = pkgs.writeShellApplication {
    name = "collection-notes";
    runtimeInputs = [config.programs.beets.package pkgs.python3];
    runtimeEnv = {
      GENERATOR = ./scripts/beets-to-vault.py;
      RELEASES_DIR = "${config.home.homeDirectory}/${vault.target}/Releases";
    };
    text = builtins.readFile ./scripts/collection-notes.sh;
  };
in {
  home.packages = [collectionNotes];

  # Obsidian vault cataloguing owned music (vinyl, CD, digital). Nix owns only
  # `.obsidian/`; the notes, template and Collection.base are seeded once from
  # templates/obsidian/collection-vault/. Every `.obsidian/` file is a store
  # symlink, so Syncthing must ignore that folder: Android can't follow them.
  #
  # A setting changed in Obsidian's UI that lives in one of the files below
  # shows no error but never reaches disk, and reverts when the vault is
  # reopened. Change it here instead. Settings not declared here (e.g.
  # appearance.json) are ordinary files and persist.
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
