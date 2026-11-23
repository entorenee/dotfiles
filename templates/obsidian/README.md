## Obsidian Template Configuration

Obsidian handles the configuration on a per vault basis. This configuration lives within a `.obsidian` folder at the root of each respective vault. There is no global configuration of Obsidian vaults at this time. The root json files inside `config/` can safely be copied and/or symlinked into an individual vault depending on preferences.

### Creating Symlinks for Configuration

These symlinks will need to be created manually as they are not captured by `rcup`. If it is desired to symlink some of the configuration files instead of a one time copy, the following can be done on a per file basis.

1. Close the Obsidian vault to avoid runtime conflicts.
2. Delete the existing file of the same name in the vault's `.obsidian` folder.
3. Run `ln -s templates/obsidian/config/[config-file] /path/to/vault/obsidian/folder`
4. Once completed open Obsidian to confirm that the settings are loaded as expected.

## Plugins and Themes

Obsidian handles plugins by git cloning the installed plugins into `.obsidian/plugins`. Maintaining plugin versions is outside the scope of this project and adds excessive amounts of bloat. I have included `data.json` files for several plugins that I use which store their configuration in JSON files. **NOTE:** some plugins include sensitive information in these files, so exercise caution if you extend this pattern.

Plugins and themes will need to be manually installed in each Obsidian vault due to the aforementioned constraints. As an optional step, plugins which store their settings in `data.json` files can have the sample values listed here copied or symlinked into the vault after plugin installation. The following are community solutions which I use regularly:

- **Theme:** Tokyo Night
- **Data Aggregation:** Dataview
- **Daily/Weekly/Monthly Notes:** Periodic Notes
- **Note encryption with GPG:** gpgCrypt
- **Notes about Books I'm reading or want to read:** Obsidian Book Search Plugin
- **Recipe Management with different views and scaling:** Recipe View

## Vault Structure

Additionally, a sample starter vault including some Templates can be found in `sample-vault/`. The intention is to copy items from here as it proves helpful. This primarily serves as a snapshot of general folder structure for consistency between my various work and personal vaults.

### Music collection vault

`collection-vault/` is the seed content for the music collection vault (vinyl, CD, digital) at `~/Music/collection`. Its `.obsidian/` settings are not here: `modules/home/music-collection` declares them through home-manager's `programs.obsidian`, on `hester-prynne` only. After a rebuild creates the vault, copy the content in once with `cp -r templates/obsidian/collection-vault/. ~/Music/collection/`.

- One note per release in `Releases/`, named `Artist - Album (Format)` so the quick switcher works as an artist or album lookup.
- New notes come from `Templates/Release.md`. `format` is `vinyl`, `cd` or `digital`; the views in `Collection.base` filter on those exact values. `source` is where it came from (a shop, Bandcamp, a gift), and has a view of its own.
- `mbid` is the MusicBrainz release ID and `discogs` the Discogs release URL. Either, both or neither may be set; each identifies the exact pressing, which keeps the data portable. CDs and digital albums are mirrored to a MusicBrainz collection by beets; vinyl is catalogued on Discogs instead, since MusicBrainz lacks most pressings.
- `condition` is the media grade and `sleeve` the sleeve grade, Goldmine-style (`M`, `NM`, `VG+`, …), matching Discogs' two condition fields.
- `discogs-notes` writes a note for each vinyl record in the Discogs collection that has none yet, matched by its `discogs` link. It is a dry run unless given `--write`, and never changes an existing note. It reads the collection through the API with the agenix token `discogs-token`, or from a website export with `--csv <file>` (no token; `year` is then the pressing's, not the original's). `mbid` is filled when MusicBrainz links that exact pressing; `--no-mb` skips the lookup. A `--write` from the API also keeps the raw responses in `~/Music/.discogs/<date>.json`.
- Property search also works without a base: `[artist:Radiohead]`, `[format:cd]`.
- Syncthing must ignore `.obsidian`: every file in it is a symlink into the Nix store, which a phone can't follow. Configure the phone's copy by hand.
