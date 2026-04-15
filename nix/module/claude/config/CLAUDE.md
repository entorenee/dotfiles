@RTK.md

# Claude Code Configuration (Nix-Managed)

This Claude Code installation is declaratively managed via Nix home-manager.
Configuration files are read-only — do NOT attempt to write to ~/.claude/settings.json directly.

## How to make changes

| Change             | Where to edit                                                                       | Then run                                   |
| ------------------ | ----------------------------------------------------------------------------------- | ------------------------------------------ |
| Add MCP server     | `nix/module/claude/work.nix` or `personal.nix` (profile-specific)                   | `make darwin-switch` or `make home-switch` |
| Add hook           | Create script in `nix/module/claude/config/hooks/`, add to `default.nix` settings   | Rebuild                                    |
| Add skill          | Add to `nix/module/claude/config/skills/`                                           | Automatic (symlinked)                      |
| Add agent          | Add to `nix/module/claude/config/agents/`                                           | Automatic (symlinked)                      |
| Change plugin      | Edit `enabledPlugins` in `nix/module/claude/default.nix`                            | Rebuild                                    |
| Change permissions | Edit `permissions` in `nix/module/claude/default.nix` (base) or profile `.nix` file | Rebuild                                    |
| Change setting     | Edit `nix/module/claude/default.nix` (base) or profile `.nix` file (override)       | Rebuild                                    |

## Important

- `~/.claude/settings.json` is a symlink to the Nix store (read-only)
- `~/.claude/hooks/`, `skills/`, `agents/` are symlinks to the dotfiles repo
- Guide the user to edit the Nix config files rather than writing directly

## Settings Merge Behavior

- Base settings in `default.nix` use `lib.mkDefault`, so profile `.nix` files can override them
- Profile-specific settings in `work.nix` / `personal.nix` are gated with `lib.mkIf` on the active profile
- Nix module system deep-merges attribute sets and concatenates lists
- For scalar values (bools, strings), profile settings override base defaults

## MCP Servers

MCP servers are declared in profile `.nix` files (e.g., `work.nix`) under `programs.claude-code.mcpServers`. The home-manager module writes these to `~/.claude.json` and they appear as `plugin:claude-code-home-manager:<name>`.

MCP servers with OAuth (e.g., Asana) require a two-part setup:

1. **Config (Nix-managed):** Add the server to the `mcpServers` attrset in the profile `.nix` file. This gets deployed via `make darwin-switch`.

2. **Auth (manual, one-time):** Run the following command to store OAuth credentials in the macOS Keychain. This only needs to be done once per machine (survives Nix rebuilds).

```bash
claude mcp add --transport http \
  --client-id "$ASANA_CLIENT_ID" \
  --client-secret \
  --callback-port 8080 \
  asana https://mcp.asana.com/v2/mcp
```

## Git

- **Never run `git add`, `git commit`, or any staging/committing commands.** I use a Yubikey for GPG commit signing which requires physical touch and does not work with automated commits. Skip all git steps — just report what files changed.

## Git Worktree Workflow

I use the **sibling worktree pattern** for all repositories:

- The parent directory (e.g., `project/`) is a container — NOT a git directory
- The primary worktree is the default branch (e.g., `project/develop`)
- Feature worktrees are siblings: `project/<branch-name>`

### Creating worktrees

Always create feature worktrees as siblings of the current worktree:

```bash
# From within any worktree (e.g., project/develop):
git worktree add ../<branch-name> -b <branch-name> <base-branch>
```

### Base branch fallback order

Use the first that exists: `develop` → `main` → `master`

### When to use worktrees

- All feature work, bug fixes, and implementation tasks should use a worktree
- Proactively create a worktree without asking — the preference is always worktrees
