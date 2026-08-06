# Dotfiles Project Overview

## Project Description

Personal dotfiles managed with Nix Darwin, including comprehensive configurations for development tools, window management, and shell environment.

## Architecture

- **Nix-based configuration management** using Darwin modules
- **Home Manager integration** for user-space configurations
- **Modular structure** with separate modules for each tool/service
- **Profile-based separation** (personal vs work configurations)

Always prefer native home-manager modules and options over custom activation scripts or manual config file edits.

When settings need to diverge by persona, **do not gate on a profile string** — there is no longer one. A module states the mechanism unconditionally, and `nix/users/personal/` (or, for the sole work machine, `nix/hosts/darwin/fw-skyler/` directly) states which persona wants it. See "Personas live in `nix/users/`" below.

### `lib.mkDefault` usage

`lib.mkDefault` only works correctly on **leaf values** or on options backed by **structured types** (submodules, `listOf`, typed options). It does **not** work on freeform/JSON-typed options (like `programs.claude-code.settings` which uses `pkgs.formats.json`).

- **Structured types** (e.g., `homebrew.brews`, `homebrew.onActivation`): `mkDefault` works as expected. Lists concatenate; submodule fields merge individually.
- **Freeform JSON types**: Wrapping the entire attrset with `lib.mkDefault` makes it a single opaque value. A higher-priority definition replaces it entirely instead of deep-merging. For these options, omit `mkDefault` on the attrset and only apply it to individual leaf values that need to be overridable.
  - That leaf case genuinely works, including *nested* inside a freeform option — priority filtering runs per attribute path, before the type's merge. `programs.ssh.settings."github.com".IdentityFile` relies on this (see "Personas live in `nix/users/`"). Wholesale-replacement is the desired behavior there, not a hazard.

## Key Components

### Core System

- **Nix Darwin** - System-level macOS configuration
- **Home Manager** - User environment and dotfile management
- **Profiles** - Separate configurations for personal/work environments

### Development Tools

- **Neovim** - Primary editor with LSP, formatting, linting via Mason
- **Tmux** - Terminal multiplexer with custom theme and keybindings (`pane-base-index 1` — panes are 1-indexed)
- **Git** - Version control with profile-specific configurations
- **Shell** - Zsh with Starship prompt

### Applications & Services

- **Ghostty** - Terminal emulator
- **Karabiner** - Keyboard customization
- **Homebrew integration** - GUI applications and system tools
- **Launch Agents** - Background services and automation

## Directory Structure

```
├── nix/
│   ├── flake.nix                 # Main flake configuration
│   ├── system/darwin.nix         # macOS system configuration
│   ├── overlays/                 # one file per overlay; hosts opt into the ones they need
│   ├── hosts/                    # INSTANTIATION — one file per machine, keyed by hostname
│   │   ├── nixos/                # The three Raspberry Pi hosts
│   │   │   ├── common.nix        # Shared base for every Pi host
│   │   │   ├── uptime.nix        # uptime-kuma + cloudflared (Pi Zero 2W)
│   │   │   ├── hub.nix           # Building hub (Pi 4, always-on)
│   │   │   └── airgap.nix        # Yubikey airgap workflow (Pi Zero 2W)
│   │   ├── darwin/                # {username, user, system, extraHomeImports?, overlays?} for each Mac
│   │   │   ├── fw-skyler/         # work dissolves fully here — only work machine, no users/work/
│   │   │   │   ├── default.nix   # the host triple ({user = ./.;})
│   │   │   │   ├── home.nix, darwin.nix, claude.nix, gh-dash.yml, id_rsa_yubikey_work.pub
│   │   │   └── lyra-sylvertongue.nix
│   │   └── home/                  # {username, user, system, extraHomeImports?, overlays?} for standalone home-manager hosts
│   │       └── hester-prynne.nix
│   ├── roles/                    # POLICY — which modules a class of machine wants
│   │   └── home/
│   │       ├── minimal.nix       # Shell, prompt, bare editor, small local CLI tools
│   │       ├── base.nix          # minimal + git, ssh, gnupg, bins, nvim config
│   │       ├── cli.nix           # base + dev tooling and language runtimes
│   │       └── gui.nix           # cli + terminal emulators, fonts, desktop apps
│   ├── users/                    # IDENTITY — what a persona means (personal only; work lives on its host)
│   │   └── personal/             # home.nix (portable) + desktop.nix (GUI add-on) + darwin.nix + claude.nix + gh-dash.yml
│   └── modules/                  # MECHANISM — how each tool is configured
│       ├── options.nix           # The `my.*` capability options (both systems)
│       ├── darwin/               # nix-darwin modules (homebrew, launch-agents)
│       └── home/                 # home-manager modules
│           ├── nvim/             # Neovim configuration
│           ├── tmux/             # Tmux configuration
│           ├── git/              # Git configuration
│           └── [tool]/           # Other tool configurations
├── templates/                    # Configuration templates
└── .claude/                      # Claude AI memory files
```

### Adding a home-manager module

`nix/modules/home/<tool>/` defines *how* a tool is configured and says nothing about who wants it. A module is not live until a role imports it — add it to exactly one of `nix/roles/home/{minimal,base,cli,gui}.nix`, which stack (`gui` → `cli` → `base` → `minimal`). Every current machine takes `gui`, so anything added there reaches all of them. Pick the *lowest* tier that is honest: `minimal` is the floor and must stay safe on an airgapped, memory-constrained host, so nothing there may assume a network, a remote, or a `~/dotfiles` checkout. See `CONVENTIONS.md` for the per-tier table and the "compose downward, don't subtract" rule.

Divergence follows a three-way rule:

| Kind | Mechanism |
| --- | --- |
| Platform truth | `pkgs.stdenv.isDarwin` / `isLinux` |
| Capability | a `my.*` option in `nix/modules/options.nix` |
| Identity (work vs personal) | an import in `nix/users/personal/` (work: directly on `nix/hosts/darwin/fw-skyler/`) |

Do **not** reach for `pkgs.stdenv.isLinux` to mean "has a GUI" — that only reads correctly while the sole Linux host happens to be a desktop. Use `config.my.gui`.

### Adding a package override or patch: `nix/overlays/`

Package-level overrides (pin a version, patch a `.desktop` file, override a build flag) go in `nix/overlays/<name>.nix`, one overlay function per file — not inside a home-manager module's `nixpkgs.overlays`. Setting `nixpkgs.overlays`/`nixpkgs.config` from inside a home-manager module is a no-op (or an error, on newer home-manager) once a host sets `home-manager.useGlobalPkgs = true`, since there's no separate pkgs left for the module to configure.

**Overlays are opt-in per host, like `extraHomeImports`, not applied globally.** Each `nix/hosts/{darwin,home}/<hostname>.nix` file can set `overlays = [(import ../../overlays/<name>.nix) ...];` alongside its `{username, user, system}` triple; a host that doesn't need an overlay simply omits the field (`host.overlays or []` in `flake.nix`). `hosts/home/hester-prynne.nix` takes `protonmail-desktop.nix` (the package only ever appears in that host's Linux-only list); `hosts/darwin/fw-skyler/default.nix` takes `pnpm-pin.nix` (the pin is for a work-only monorepo). `lyra-sylvertongue.nix` takes neither. `flake.nix`'s `mkDarwinHost`/`mkHomeHost` read the host's `overlays` list and pass it through `mkDarwinConfig`/`mkHomeManagerConfig` to wherever that config's pkgs is actually built (`system/darwin.nix`'s nix-darwin-level `nixpkgs.overlays` for Darwin — both hosts run `home-manager.useGlobalPkgs = true`, so home-manager shares that pkgs automatically; `flake.nix`'s `mkHomeManagerConfig` builds `pkgs` directly for the standalone Linux host).

### Personas live in `nix/users/`

There is no `profile` argument. A persona is a **directory that gets imported**, and the flake picks it by path:

| File | Sets |
| --- | --- |
| `users/<persona>/home.nix` | home-manager options: portable packages, ssh identities, gh-dash config, persona-only module imports safe on any machine that persona touches, headless or not |
| `users/<persona>/darwin.nix` | nix-darwin options: Homebrew taps/brews/casks, launch agents, the Dock |
| `users/<persona>/claude.nix` | `programs.claude-code` additions, imported by `home.nix` |

Two files because persona spans both module systems — a home-manager module cannot set `homebrew.casks`.

**`work` has only one machine, so it isn't a `users/` persona at all — it lives directly on its host.** `nix/hosts/darwin/fw-skyler/` holds `home.nix`/`darwin.nix`/`claude.nix`/`gh-dash.yml`/the work Yubikey public key, exactly the same shape `users/work/` used to be, just with no persona indirection to a second consumer that will never exist. A persona directory only earns its keep once two or more hosts share it — `personal` does (the personal Mac and the Linux desktop), so it stays under `users/`.

**A module that only one persona wants is imported from that persona's `home.nix` (or its GUI-only `desktop.nix`, see below), not from a role.** `keepassxc` and `orca-slicer` work this way; putting them in `roles/home/gui.nix` would mean gating them back off. Roles carry what a *class of machine* wants; `users/` carries what a *person* wants.

**Split a persona's `home.nix` into a portable base plus opt-in add-ons once it needs to reach a headless host.** `users/personal/home.nix` is the portable subset (claude.nix, gh-dash, syncthing) — safe for a future headless personal Pi. The GUI-desktop-only pieces (keepassxc, orca-slicer, `go`/`hugo`) live in `users/personal/desktop.nix` instead, and a host opts into it via `extraHomeImports` on its `nix/hosts/{darwin,home}/<hostname>.nix` file (a list of extra home-manager module paths, spliced in alongside `user + "/home.nix"`). Both current personal hosts (`lyra-sylvertongue`, `hester-prynne`) set it; a future headless personal Pi would import `users/personal` without it. Don't fold `desktop.nix` back into `home.nix` — that's exactly the coupling this split removes.

Most options merge across the two, so a persona file **adds** to a module rather than replacing it — `home.packages` and `homebrew.casks` are `listOf` (concatenate), `launchd.user.agents` is an attrset of submodules (merges).

**When a list won't concatenate, use base-default + host-replacement.** Freeform `types.anything` options (`programs.ssh.settings` is the one in this repo) *throw* on two list definitions rather than concatenating, so a persona (or host) cannot append. Don't respond by moving the whole value into the persona/host files — state the common case in the module as a `lib.mkDefault` and let the one that needs something else replace it:

```nix
# modules/home/ssh/default.nix — what most machines need
settings."github.com" = {
  IdentityFile = lib.mkDefault [personalYubikeyIdentity];
  IdentitiesOnly = true;
};

# hosts/darwin/fw-skyler/home.nix — the machine that needs more
programs.ssh.settings."github.com".IdentityFile = [personalYubikeyIdentity workYubikeyIdentity];
```

This works because **priority filtering runs before the type's merge function**, so exactly one definition ever reaches it and there is nothing to conflict. Sibling attributes are unaffected: `IdentitiesOnly` still comes from the module in all three configurations. The cost is that the replacement restates the whole list.

Persona/host ordering in merged lists is not stable — `users/` and `hosts/` definitions may land before or after a module's. Nothing currently depends on it (Homebrew installs a set; `permissions.allow` matches by any-match), but do not introduce anything that does.

## Management Commands

- **Rebuild and switch:** `make rebuild` — auto-detects OS (Darwin vs Linux) and picks the flake attribute from the machine's hostname (`hostname -s`).
- **Host selection:** flake outputs are keyed by hostname (`fw-skyler`, `lyra-sylvertongue`, `hester-prynne`). Each `nix/hosts/{darwin,home}/<hostname>.nix` file states `{username, user, system, extraHomeImports ? [], overlays ? []}`; `user` is a `./users/<persona>` path (`fw-skyler` points at itself, since work has no separate persona directory — see "Personas live in `nix/users/`" below).

## NixOS Pi Hosts

Three `nixosConfigurations` live in `nix/hosts/`, all `aarch64-linux`: `hub` (the always-on Pi 4, general building hub), `airgap` (the airgapped Yubikey Pi Zero 2W), and `uptime` (the uptime-kuma Pi Zero 2W).

| Task | Command | Run from |
| --- | --- | --- |
| Build the airgap Zero image | `make airgap-image` | hub |
| Build the uptime image | `make uptime-image` | hub |
| Deploy to the uptime Zero | `make uptime-switch` (override `UPTIME_HOST`) | hub |
| Rebuild the hub itself | `make hub-switch` | hub |

### Never import nixos-hardware into an sd-image host

`nixos-hardware`'s `raspberry-pi-*` modules `mkForce`-replace `populateFirmwareCommands` from `sd-image-aarch64.nix`. Their replacement only installs `u-boot.bin` (and the matching `kernel=` / `arm_64bit=1` lines in `config.txt`) when `hardware.raspberry-pi.firmware.uboot.enable` is set. Left off, the firmware partition gets `bootcode.bin`/`start.elf`/dtbs but **no kernel**, so the GPU firmware has nothing to hand off to and the board dies with **7 LED flashes**.

Enabling `uboot` papers over it; dropping `nixos-hardware` is the actual fix, and also removes the need to re-set `hardware.raspberry-pi.configtxt.settings.pi02.core_freq = 250` to keep serial output from garbling. So an image-built host imports **stock `sd-image-aarch64.nix` and nothing else**.

`hub.nix` is the exception and is correct as written: it is installed in place and rebuilt with `nixos-rebuild switch`, so the sd-image module is never in play. Do not "fix" the asymmetry, and do not use `hub.nix` as the template for a new image-built host.

`nix/hosts/common.nix` also sets `boot.supportedFilesystems.zfs = lib.mkForce false`. This is load-bearing, not cosmetic — the sd-image default pulls ZFS in and it will not build for the aarch64 image.

### A Pi Zero cannot rebuild itself

A Zero 2W has 512MB of RAM. *Evaluating* a NixOS closure peaks well above that before any compilation starts, so an on-device `nixos-rebuild` means swapping onto the SD card for a very long time. Deploy instead: `make uptime-switch` runs on the hub, which evaluates and builds natively for aarch64 and pushes only the resulting closure. The Zero just activates it. The dotfiles clone on the Zero is for reading and editing config, not for rebuilding.

### Secrets on the uptime host

Nothing about the Cloudflare tunnel is in this repo. `nix/hosts/uptime.nix` runs a hand-rolled `cloudflared-tunnel` unit rather than `services.cloudflared`, because that module takes the tunnel UUID as an attribute name and renders ingress rules into a store-built `config.yml` — both eval-time inputs, and both things that would end up published in this repo.

Seed the host by placing two files in `/etc/cloudflared`, either on the mounted image before flashing or over SSH afterwards:

- `config.yml` — tunnel UUID, `credentials-file: /etc/cloudflared/credentials.json`, and an ingress rule pointing the public hostname at `http://127.0.0.1:3001`
- `credentials.json` — from `cloudflared tunnel create`

`systemd.tmpfiles` `z` rules re-apply `root:cloudflared` `0640` to both on every boot, so seeding them on a build machine where the `cloudflared` uid does not exist yet still works. Until `config.yml` exists the unit's `ConditionPathExists` keeps it inert instead of crash-looping.

## Claude Code Nix Module

The Claude Code configuration is Nix-managed in `nix/modules/home/claude/`. The global `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, hooks, skills, and agents are all symlinks managed by this repo.

### How to make changes

| Change             | Where to edit                                                                       | Then run                                   |
| ------------------ | ----------------------------------------------------------------------------------- | ------------------------------------------ |
| Add MCP server     | `nix/hosts/darwin/fw-skyler/claude.nix` or `nix/users/personal/claude.nix`                 | `make darwin-switch` or `make home-switch` |
| Add hook           | Create script in `nix/modules/home/claude/config/hooks/`, add to `default.nix` settings   | Rebuild                                    |
| Add skill          | Add to `nix/modules/home/claude/config/skills/`                                           | Automatic (symlinked)                      |
| Add agent          | Add to `nix/modules/home/claude/config/agents/`                                           | Automatic (symlinked)                      |
| Change plugin      | Edit `enabledPlugins` in `nix/modules/home/claude/default.nix`                            | Rebuild                                    |
| Change permissions | Edit `permissions` in `nix/modules/home/claude/default.nix` (base), `nix/hosts/darwin/fw-skyler/claude.nix` (work), or `nix/users/personal/claude.nix` (personal) | Rebuild |
| Change setting     | Edit `nix/modules/home/claude/default.nix` (base), `nix/hosts/darwin/fw-skyler/claude.nix` (work), or `nix/users/personal/claude.nix` (personal) | Rebuild |

### Symlink Layout

- `~/.claude/settings.json` → Nix store (read-only)
- `~/.claude/hooks/`, `skills/`, `agents/` → this dotfiles repo

Because `hooks/` is an out-of-store symlink into this repo, a new or edited hook script is live the moment it is written — no rebuild needed to *run* it. A rebuild is still required to *register* it in `settings.json`.

### Quit Claude sessions before rebuilding

**`make rebuild` while a Claude Code session is running deletes `~/.claude/settings.json`.** Quit all sessions first, rebuild, then restart them.

`make rebuild` now refuses to run when it detects a live session, listing each one so you know what to quit. `make claude-sessions` shows the same list on its own. Override with `make rebuild FORCE=1` when you accept the loss. Note that `pgrep -x claude` undercounts when run *from inside* a Claude Code session (it misses the invoking process), so run these from a plain terminal.

The home-manager `claude-code` module deploys settings.json as a symlink to a store file installed `-Dm444` (`modules/programs/claude-code/default.nix`), so it is read-only. When a rebuild swaps that symlink to a new generation with different content, a *running* Claude Code process notices the change a few minutes later and tries to write the file back; it cannot write the read-only target in place, so it unlinks first and the write never lands. The symlink is simply gone, and with it every permission rule — so everything starts prompting, silently.

Verified 2026-07-28 on claude-code 2.1.220, five trials: three rebuilds with a session running all lost the file within ~5 minutes; a rebuild with no session running kept it; and manually relinking to the *same* store target (no content change) survived 21 minutes. So the trigger is a content change observed by a live process, not the rebuild alone.

**To recover: quit all sessions and re-run `make rebuild`.** Then confirm with `jq '.permissions.allow | length' ~/.claude/settings.json` — the failure mode is a missing file, not a malformed one, so any successful `jq` read means it is back.

Do not try to reconstruct the symlink from the home-manager profile paths. Under nix-darwin they diverge: verified 2026-07-28, `~/.local/state/nix/profiles/home-manager/home-files/` had no `.claude/settings.json` at all, `~/.local/state/home-manager/gcroots/current-home/` pointed at a stale generation, and the live symlink pointed at a third — because home-manager runs as a nix-darwin module, so the authoritative `home-manager-files` derivation is referenced from the system generation rather than the home-manager profile. If you must relink by hand, take the target from `readlink ~/.claude/settings.json` *before* it disappears.

### Settings Merge Behavior

- `programs.claude-code.settings` uses a freeform JSON type (`pkgs.formats.json`) — do **not** wrap the entire attrset with `lib.mkDefault` (it prevents merging; see Architecture section above)
- Base settings in `default.nix` are set without `mkDefault`; the JSON type merges attrsets across definitions automatically
- Persona settings live in `nix/users/personal/claude.nix` or (for work) `nix/hosts/darwin/fw-skyler/claude.nix`, and are **not** gated — the file is only imported by the machine that wants it, so no `lib.mkIf` is involved
- For individual leaf values that a persona needs to override, apply `lib.mkDefault` to that specific value in `default.nix`
- List-valued settings (`permissions.allow`, `sandbox.filesystem.allowRead`) concatenate across the two files, but **the resulting order is not guaranteed** — persona entries may precede or follow the base ones. Fine for allow-matching; do not add anything order-sensitive. Hook arrays are order-sensitive and are defined only in `default.nix` for this reason.

### MCP Servers

MCP servers are declared in `nix/users/personal/claude.nix` or `nix/hosts/darwin/fw-skyler/claude.nix` under `programs.claude-code.mcpServers`. The home-manager module writes these to `~/.claude.json` and they appear as `plugin:claude-code-home-manager:<name>`.

MCP servers with OAuth (e.g., Asana) require a two-part setup:

1. **Config (Nix-managed):** Add the server to the `mcpServers` attrset in the relevant `claude.nix`. This gets deployed via `make darwin-switch`.

2. **Auth (manual, one-time):** Run the following command to store OAuth credentials in the macOS Keychain. This only needs to be done once per machine (survives Nix rebuilds).

```bash
claude mcp add --transport http \
  --client-id "$ASANA_CLIENT_ID" \
  --client-secret \
  --callback-port 8080 \
  asana https://mcp.asana.com/v2/mcp
```

#### Google Drive (`googledrive`, work profile)

The official Google-hosted Drive MCP server (`https://drivemcp.googleapis.com/mcp/v1`) is bring-your-own-OAuth-client — there's no shared Anthropic app, so you must register a Google Cloud OAuth client before auth works.

1. **Google Cloud (one-time):** In a Google Cloud project, enable both the **Google Drive API** and the **Google Drive MCP API**. Configure the OAuth consent screen with scopes `drive.readonly` and `drive.file`, then create an **OAuth 2.0 Web application** client with redirect URI `https://claude.ai/api/mcp/auth_callback`. Note the client ID and secret.

2. **Auth (manual, one-time per machine):** Store the credentials in the Keychain and complete the OAuth flow:

```bash
claude mcp add --transport http \
  --client-id "$GDRIVE_CLIENT_ID" \
  --client-secret \
  --callback-port 8080 \
  googledrive https://drivemcp.googleapis.com/mcp/v1
```

The server exposes `create_file`, which converts uploaded markdown into a native Google Doc — this is what lets the investigation skills export reports to Drive. Only `create_file` and the read-only tools are allowlisted; `copy_file` prompts each time.

### Permissions

Claude Code permissions live in `nix/modules/home/claude/default.nix` (base) with additions in `nix/users/personal/claude.nix` or `nix/hosts/darwin/fw-skyler/claude.nix`. Three coordinated layers:

| Layer | Field | Behavior |
| --- | --- | --- |
| Allow | `permissions.allow` | Glob patterns auto-approve matching tool calls |
| Deny | `permissions.deny` | Always wins over allow — use for defense in depth |
| Sandbox | `sandbox.network.allowedDomains`, `sandbox.filesystem.allowRead/Write` | Hard boundary that no per-call approval can bypass |

#### Pattern syntax

All tools use the same glob style — `*` matches any string, anywhere in the pattern:

- `Bash(git --no-pager *)` — wildcard after a flag
- `Bash(gh api repos/*/issues*)` — wildcard mid-path
- `mcp__plugin_claude-code-home-manager_expo__*_info` — wildcard mid-name (matches `build_info`, `workflow_info`)
- `Skill(superpowers:*)` — wildcard after plugin namespace

#### Condensing MCP allowlists

MCP tools typically share verb prefixes: `get_`, `list_`, `search_`, `find_`, `whoami` (read) vs. `create_`, `delete_`, `edit_`, `update_`, `add_`, `remove_`, `move_`, `import_`, `rename_`, `toggle_`, `acknowledge_`, `escalate_`, `resolve_`, `reopen_` (write). Use glob patterns on the read-only verb prefixes (e.g., `mcp__asana__get_*`, `mcp__asana__search_*`) instead of enumerating each tool — mutating tools won't match because their verbs are different.

When verb prefixes are mixed (e.g., Expo's `build_info` is read but `build_run` is write), use suffix globs like `*_info`, `*_list`, `*_logs` to capture the read shape without catching writes.

#### Defense-in-depth for broad allows

`Bash(gh api*)` is allowlisted broadly because the deny list blocks every write verb (`-X POST/PATCH/PUT/DELETE`, `-f`, `--field`). Pattern: broad allow on the read surface + targeted denies on the write verbs. Deny wins, so the broad allow is safe.

#### Custom skills and commands — **important**

Custom skills (in `nix/modules/home/claude/config/skills/`) and custom slash commands (in `nix/modules/home/claude/config/commands/`) both have no plugin namespace, so they can't be matched by a wildcard. They also share the same permission gate — `/<name>` invokes the Skill tool whether the underlying file is a `SKILL.md` or a command `.md`.

**When adding a new custom skill OR command, also add a matching `Skill(<name>)` entry to `permissions.allow`** in `default.nix`. Otherwise it prompts for approval the first time it's used in every new worktree.

Plugin-distributed skills *are* namespaced (e.g., `superpowers:executing-plans`, `pr-review-toolkit:review-pr`), so a single glob per plugin namespace (`Skill(superpowers:*)`) trusts the entire plugin's skill set in one entry.

#### Built-in auto-allows

Claude Code auto-approves many read-only commands by default — most `git` subcommands (`status`, `log`, `diff`, `show`, `blame`, `branch`, `tag`, `remote`, `ls-files`, `rev-parse`, `describe`, `stash list`, `worktree list`), `gh pr/issue/run view/list`, `gh api` GET, and common Unix utilities (`ls`, `cat`, `head`, `tail`, `grep`, `rg`, `find`, etc.). Explicit allowlist entries for these are redundant but harmless — they document intent and remain stable if built-in behavior changes.

## GitHub CLI Usage

The `gh` config has `prefer_editor_prompt: enabled`, which blocks in non-TTY contexts like Claude Code. When creating GitHub issues or PRs programmatically, use `gh api` directly:

```bash
# Instead of: gh issue create --title "..." --body "..."
gh api repos/{owner}/{repo}/issues -X POST -f title="..." -f body="..."

# Instead of: gh pr create --title "..." --body "..."
gh api repos/{owner}/{repo}/pulls -X POST -f title="..." -f body="..." -f head="..." -f base="..."
```

## Claude AI Memory Files

### Neovim Configuration

- **File:** [.claude/nvim-language-patterns.md](.claude/nvim-language-patterns.md)
- **Purpose:** Documents patterns for language-specific neovim configurations
- **When to reference:** Making changes to language support, LSP, formatting, or linting

### Guidelines for Claude

1. **Always check memory files first** before making configuration changes
2. **Follow established patterns** documented in memory files
3. **Update memory files** when patterns change or new patterns emerge
4. **Maintain consistency** with existing configuration style and structure

### CLAUDE.md vs Local Memory

This repo is used across multiple machines. Use the right persistence layer:

| What to store | Where | Why |
| --- | --- | --- |
| Project patterns, tool conventions, CLI gotchas | `CLAUDE.md` (this file) | Travels with the repo; available on every machine |
| User preferences, role, feedback on Claude behavior | Local memory (`~/.claude/projects/.../memory/`) | Personal to the user/machine; not repo-specific |

**Rule of thumb:** If another Claude session on a different machine would need this info to work effectively in this repo, it belongs in `CLAUDE.md`. If it's about *how the user wants Claude to behave generally*, it belongs in local memory.

## Configuration Principles

- **Modularity** - Each tool has its own module
- **Profile awareness** - Configurations adapt to personal/work contexts
- **Declarative** - All configurations are explicitly defined
- **Version controlled** - Everything is tracked in git
- **Reproducible** - Configurations can be applied to new machines

## Key Features

- **Automatic tool installation** via Nix packages and Homebrew
- **Cross-profile consistency** with profile-specific overrides
- **Integrated development environment** with LSP, formatting, linting
- **Custom keybindings** and shortcuts across all tools
- **Backup and sync** via git repository

## Getting Started

1. Clone repository
2. Review profile settings in `flake.nix`
3. Run `make darwin-switch` to apply configurations
4. Customize individual modules as needed

## Maintenance Notes

- **Regular updates:** Keep flake.lock updated
- **Profile testing:** Test changes in both personal/work profiles
- **Documentation:** Update memory files when patterns change
- **Backup:** Configurations are version controlled but consider additional backups for sensitive data

