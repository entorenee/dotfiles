@RTK.md

# Claude Code Configuration (Nix-Managed)

This Claude Code installation is declaratively managed via Nix home-manager.
Configuration files are read-only — do NOT attempt to write to `~/.claude/settings.json` directly.
Guide the user to edit the Nix config files in their dotfiles repo rather than writing directly.

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
