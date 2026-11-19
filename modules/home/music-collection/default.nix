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

  # Add a vault note for every Discogs vinyl record that lacks one. Dry-run by
  # default; pass --write.
  discogsNotes = pkgs.writeShellApplication {
    name = "discogs-notes";
    runtimeInputs = [pkgs.python3];
    runtimeEnv = {
      GENERATOR = ./scripts/discogs-to-vault.py;
      RELEASES_DIR = "${config.home.homeDirectory}/${vault.target}/Releases";
      SNAPSHOT_DIR = "${config.home.homeDirectory}/Music/.discogs";
      DISCOGS_TOKEN_FILE = config.age.secrets.discogs-token.path;
    };
    text = ''python3 -I "$GENERATOR" "$RELEASES_DIR" "$SNAPSHOT_DIR" "$@"'';
  };
in {
  home.packages = [collectionNotes discogsNotes];

  # Discogs personal access token, read by discogs-notes.
  age.secrets.discogs-token = {
    file = ../../../secrets/discogs-token.age;
    path = "${config.xdg.configHome}/discogs/token";
    mode = "0400";
  };

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
