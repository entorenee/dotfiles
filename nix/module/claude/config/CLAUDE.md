@RTK.md

# Claude Code Configuration (Nix-Managed)

This Claude Code installation is declaratively managed via Nix home-manager.
Configuration files are read-only — do NOT attempt to write to ~/.claude/settings.json directly.

## How to make changes

| Change | Where to edit | Then run |
|--------|--------------|----------|
| Add MCP server | `nix/module/claude/config/settings-base.json` (shared) or `settings-work.json` / `settings-personal.json` (profile-specific) | `make darwin-switch` or `make home-switch` |
| Add hook | Create script in `nix/module/claude/config/hooks/`, add to settings JSON | Rebuild |
| Add skill | Add to `nix/module/claude/config/skills/` | Automatic (symlinked) |
| Add agent | Add to `nix/module/claude/config/agents/` | Automatic (symlinked) |
| Change plugin | Edit `enabledPlugins` in `settings-base.json` | Rebuild |
| Change permissions | Edit `permissions` in settings JSON | Rebuild |

## Important
- `~/.claude/settings.json` is a symlink to the Nix store (read-only)
- `~/.claude/hooks/`, `skills/`, `agents/` are symlinks to the dotfiles repo
- Guide the user to edit the Nix config files rather than writing directly
