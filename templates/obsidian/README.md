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

* **Theme:** Tokyo Night
* **Data Aggregation:** Dataview
* **Daily/Weekly/Monthly Notes:** Periodic Notes
* **Note encryption with GPG:** gpgCrypt
* **Notes about Books I'm reading or want to read:** Obsidian Book Search Plugin
* **Recipe Management with different views and scaling:** Recipe View

