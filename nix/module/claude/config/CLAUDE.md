@RTK.md

# Claude Code Configuration (Nix-Managed)

This Claude Code installation is declaratively managed via Nix home-manager.
Configuration files are read-only — do NOT attempt to write to ~/.claude/settings.json directly.

## How to make changes

| Change             | Where to edit                                                                                                                | Then run                                   |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| Add MCP server     | `nix/module/claude/config/settings-base.json` (shared) or `settings-work.json` / `settings-personal.json` (profile-specific) | `make darwin-switch` or `make home-switch` |
| Add hook           | Create script in `nix/module/claude/config/hooks/`, add to settings JSON                                                     | Rebuild                                    |
| Add skill          | Add to `nix/module/claude/config/skills/`                                                                                    | Automatic (symlinked)                      |
| Add agent          | Add to `nix/module/claude/config/agents/`                                                                                    | Automatic (symlinked)                      |
| Change plugin      | Edit `enabledPlugins` in `settings-base.json`                                                                                | Rebuild                                    |
| Change permissions | Edit `permissions` in settings JSON                                                                                          | Rebuild                                    |

## Important

- `~/.claude/settings.json` is a symlink to the Nix store (read-only)
- `~/.claude/hooks/`, `skills/`, `agents/` are symlinks to the dotfiles repo
- Guide the user to edit the Nix config files rather than writing directly

## Settings Merge Behavior

- `lib.recursiveUpdate` performs a deep merge of base + profile settings
- **Arrays are replaced, not appended** — profile arrays overwrite base arrays at the same path
- Sandbox permissions with profile-specific paths (e.g., `~/code/work`) must include shared paths (e.g., `~/dotfiles`) in each profile file
- Keep this in mind when adding any array-valued settings to both base and profile configs

## MCP Servers

MCP servers with OAuth (e.g., Asana) require a two-part setup:

1. **Config (Nix-managed):** Add the non-secret fields (`type`, `url`, `clientId`, `callbackPort`) to the appropriate settings JSON file. This gets deployed via `make darwin-switch`.

2. **Secret (manual, one-time):** Run `claude mcp add` with `--client-secret` to store the secret in the macOS Keychain. This only needs to be done once per machine (survives Nix rebuilds).

Example for Asana:

```bash
claude mcp add --transport http \
  --client-id YOUR_CLIENT_ID \
  --client-secret \
  --callback-port 8080 \
  asana https://mcp.asana.com/v2/mcp
```

If the server entry already exists from Nix, you only need to re-run this command to populate the keychain secret (e.g., after a credential rotation or on a new machine).

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
