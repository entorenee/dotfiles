{ config, lib, profile, ... }:
let
  configPath = "${config.home.homeDirectory}/dotfiles/nix/module/claude/config";
in {
  imports = [./work.nix ./personal.nix];

  programs.claude-code = {
    enable = true;
    settings = lib.mkDefault {
      hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "~/.claude/hooks/rtk-rewrite.sh";
            }
          ];
        }
      ];
      enabledPlugins = {
        "typescript-lsp@claude-plugins-official" = true;
        "superpowers@superpowers-marketplace" = true;
        "frontend-design@claude-plugins-official" = true;
      };
      sandbox.enabled = true;
      statusLine = {
        type = "command";
        command = "~/.claude/statusline.sh";
      };
      hasSentTelemetryConsent = false;
      preferences = {
        alwaysThinkingEnabled = true;
        cleanupPeriodDays = 365;
      };
      permissions.deny = [
        "Bash(rm -rf *)"
        "Bash(rm -fr *)"
        "Bash(sudo *)"
        "Bash(mkfs *)"
        "Bash(dd *)"
        "Bash(wget *|bash*)"
        "Bash(wget *| bash*)"
        "Bash(curl *|bash*)"
        "Bash(curl *| bash*)"
        "Bash(curl *|sh*)"
        "Bash(curl *| sh*)"
        "Bash(chmod 777 *)"
        "Bash(git push --force*)"
        "Bash(git push *--force*)"
        "Bash(git reset --hard*)"
        "Bash(git commit*)"
        "Edit(~/.bashrc)"
        "Edit(~/.zshrc)"
        "Edit(~/.ssh/**)"
        "Read(~/.ssh/**)"
        "Read(~/.gnupg/**)"
        "Read(~/.aws/**)"
        "Read(~/.azure/**)"
        "Read(~/.config/gh/**)"
        "Read(~/.git-credentials)"
        "Read(~/.docker/config.json)"
        "Read(~/.kube/**)"
        "Read(~/.npmrc)"
        "Read(~/.npm/**)"
        "Read(~/.pypirc)"
        "Read(~/.gem/credentials)"
        "Read(~/Library/Keychains/**)"
      ];
    };
  };

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
