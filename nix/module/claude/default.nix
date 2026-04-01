{ config, lib, profile, ... }:
let
  claudeModulePath = "${config.home.homeDirectory}/dotfiles/nix/module/claude";
  configPath = "${claudeModulePath}/config";
  baseSettings = builtins.fromJSON (builtins.readFile ./config/settings-base.json);
  profileSettings = builtins.fromJSON (
    builtins.readFile (
      if profile == "work"
      then ./config/settings-work.json
      else ./config/settings-personal.json
    )
  );

  mergedSettings = lib.recursiveUpdate baseSettings profileSettings;
  settingsJson = builtins.toJSON mergedSettings;
in {
  home.file.".claude/settings.json".text = settingsJson;

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/CLAUDE.md";
  home.file.".claude/RTK.md".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/RTK.md";

  home.file.".claude/hooks".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/hooks";

  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/skills";

  home.file.".claude/agents".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/agents";

  home.file.".claude/statusline.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${configPath}/statusline.sh";
}
