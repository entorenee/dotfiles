{ config, lib, profile, ... }:
let
  configPath = "${config.home.homeDirectory}/dotfiles/nix/module/claude/config";
in {
  imports = [./work.nix ./personal.nix];

  programs.claude-code = {
    enable = true;
    settings = {
      hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "~/.claude/hooks/pnpm-guard.sh";
            }
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
        "lua-lsp@claude-plugins-official" = true;
        "pr-review-toolkit@claude-plugins-official" = true;
      };
      env = {
        ENABLE_CLAUDEAI_MCP_SERVERS = "false";
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
      permissions.allow = [
        # Read access for dotfiles (skills, agents, nix modules)
        "Read(~/dotfiles/**)"
        "Read(/nix/store/**)"
        # gh cli read-only
        "Bash(gh issue list*)"
        "Bash(gh issue view*)"
        "Bash(gh pr list*)"
        "Bash(gh pr view*)"
        "Bash(gh pr status*)"
        "Bash(gh pr checks*)"
        "Bash(gh pr diff*)"
        "Bash(gh pr create*)"
        "Bash(gh run list*)"
        "Bash(gh run view*)"
        "Bash(gh repo view*)"
        "Bash(gh api repos/*/issues*)"
        "Bash(gh api repos/*/pulls*)"
        # rtk wrapper (transparent proxy for token savings)
        "Bash(rtk *)"
        # git read-only
        "Bash(git log*)"
        "Bash(git diff*)"
        "Bash(git show*)"
        "Bash(git branch*)"
        "Bash(git blame*)"
        "Bash(git stash list*)"
        "Bash(git worktree list*)"
        "Bash(git remote*)"
        "Bash(git rev-parse*)"
        "Bash(git merge-base*)"
        "Bash(git tag*)"
        "Bash(git describe*)"
        "Bash(git ls-files*)"
        # npm read-only
        "Bash(npm ls*)"
        "Bash(npm outdated*)"
        "Bash(npm explain*)"
        "Bash(npm view*)"
        "Bash(npm pkg get*)"
        "Bash(npm audit*)"
        "Bash(npm run --list*)"
        # npm build/test
        "Bash(npm test*)"
        "Bash(npm run test*)"
        "Bash(npm run lint*)"
        "Bash(npm run tsc*)"
        "Bash(npm run build*)"
        "Bash(npm run dev*)"
        "Bash(npm ci*)"
        "Bash(npm install*)"
        # pnpm read-only
        "Bash(pnpm ls*)"
        "Bash(pnpm list*)"
        "Bash(pnpm outdated*)"
        "Bash(pnpm view*)"
        "Bash(pnpm why *)"
        "Bash(pnpm audit*)"
        # pnpm build/test
        "Bash(pnpm test*)"
        "Bash(pnpm run test*)"
        "Bash(pnpm run lint*)"
        "Bash(pnpm run tsc*)"
        "Bash(pnpm run typecheck*)"
        "Bash(pnpm run build*)"
        "Bash(pnpm run dev*)"
        "Bash(pnpm install*)"
        "Bash(pnpm add*)"
        "Bash(pnpm exec *)"
        # turbo
        "Bash(pnpm turbo *)"
        "Bash(npx turbo *)"
        # typescript direct
        "Bash(npx tsc*)"
        "Bash(tsc *)"
        # test runner
        "Bash(npx vitest *)"
        # linter (read-only by default; --fix mutates)
        "Bash(npx eslint *)"
        # expo
        "Bash(npx expo *)"
        # nix read-only
        "Bash(nix eval *)"
        "Bash(nix flake show*)"
        "Bash(nix flake metadata*)"
        "Bash(nix run home-manager*)"
        "Bash(darwin-rebuild switch*--dry-run*)"
      ];
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
        # Block posting comments/reviews on GitHub on my behalf
        "Bash(gh pr comment*)"
        "Bash(gh pr review*)"
        "Bash(gh pr close*)"
        "Bash(gh pr merge*)"
        "Bash(gh pr edit*)"
        "Bash(gh issue comment*)"
        "Bash(gh issue create*)"
        "Bash(gh issue close*)"
        "Bash(gh issue edit*)"
        "Bash(gh api *-f *)"
        "Bash(gh api *--field *)"
        "Bash(gh api *-X POST*)"
        "Bash(gh api *-X PATCH*)"
        "Bash(gh api *-X PUT*)"
        "Bash(gh api *-X DELETE*)"
        "Bash(gh api *--method POST*)"
        "Bash(gh api *--method PATCH*)"
        "Bash(gh api *--method PUT*)"
        "Bash(gh api *--method DELETE*)"
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

  programs.zsh.shellAliases = {
    claude-yolo = "claude --dangerously-skip-permissions";
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
