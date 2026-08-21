# Dotfiles Project Overview

## Project Description

Personal dotfiles managed with Nix Darwin, including comprehensive configurations for development tools, window management, and shell environment.

## Architecture

- **Nix-based configuration management** using Darwin modules
- **Home Manager integration** for user-space configurations
- **Modular structure** with separate modules for each tool/service
- **Identity roles** — personal vs work divergence is an import a host names, not a profile string

Always prefer native home-manager modules and options over custom activation scripts or manual config file edits.

When settings need to diverge by identity, **do not gate on a profile string** — there is no longer one. A module states the mechanism unconditionally, and an identity role file (`roles/home/personal.nix`, `roles/darwin/personal.nix`, or — for the sole work machine — `hosts/darwin/fw-skyler/` directly) states who wants it. See "Identity roles live in `roles/`" below.

### `lib.mkDefault` usage

`lib.mkDefault` only works correctly on **leaf values** or on options backed by **structured types** (submodules, `listOf`, typed options). It does **not** work on freeform/JSON-typed options (like `programs.claude-code.settings` which uses `pkgs.formats.json`).

- **Structured types** (e.g., `homebrew.brews`, `homebrew.onActivation`): `mkDefault` works as expected. Lists concatenate; submodule fields merge individually.
- **Freeform JSON types**: Wrapping the entire attrset with `lib.mkDefault` makes it a single opaque value. A higher-priority definition replaces it entirely instead of deep-merging. For these options, omit `mkDefault` on the attrset and only apply it to individual leaf values that need to be overridable.
  - That leaf case genuinely works, including *nested* inside a freeform option — priority filtering runs per attribute path, before the type's merge. `programs.ssh.settings."github.com".IdentityFile` relies on this (see "Identity roles live in `roles/`"). Wholesale-replacement is the desired behavior there, not a hazard.

## Key Components

### Core System

- **Nix Darwin** - System-level macOS configuration
- **Home Manager** - User environment and dotfile management
- **Roles** - Tier roles (`minimal`/`base`/`cli`/`gui`) stack; identity roles (`personal*`, or `hosts/darwin/fw-skyler/` for work) are named per host

### Development Tools

- **Neovim** - Primary editor with LSP, formatting, linting via Mason
- **Tmux** - Terminal multiplexer with custom theme and keybindings (`pane-base-index 1` — panes are 1-indexed)
- **Git** - Version control; identity-specific settings come from the role file a host imports
- **Shell** - Zsh with Starship prompt

### Applications & Services

- **Ghostty** - Terminal emulator
- **Karabiner** - Keyboard customization
- **Homebrew integration** - GUI applications and system tools
- **Launch Agents** - Background services and automation

## Directory Structure

```
├── flake.nix                     # Main flake configuration
├── system/darwin.nix             # macOS system configuration
├── overlays/                     # one file per overlay; hosts opt into the ones they need
├── lib/                          # mkDarwinHost / mkHomeHost / mkNixosHost, one file each
├── hosts/                        # INSTANTIATION — one file (or directory) per machine, keyed by hostname
│   ├── nixos/                    # The three Raspberry Pi hosts, one directory each
│   │   ├── hub/                  # Building hub (Pi 4, always-on) — the one Pi with home-manager
│   │   │   ├── default.nix       # {system, nixosImports, username?, homeImports?}
│   │   │   └── configuration.nix
│   │   ├── uptime/               # uptime-kuma + cloudflared (Pi Zero 2W)
│   │   │   ├── default.nix
│   │   │   └── configuration.nix
│   │   └── airgap/               # Yubikey airgap workflow (Pi Zero 2W)
│   │       ├── default.nix
│   │       └── configuration.nix
│   ├── darwin/                   # {username, system, homeImports, darwinImports?, overlays?} for each Mac
│   │   ├── fw-skyler/            # work dissolves fully here — only work machine, no personal-style role files
│   │   │   ├── default.nix       # the host statement; names ./home.nix and ./darwin.nix in its own import lists
│   │   │   ├── home.nix, darwin.nix, claude.nix, gh-dash.yml, id_rsa_yubikey_work.pub
│   │   └── lyra-silvertongue.nix
│   └── home/                     # same contract, for standalone home-manager hosts
│       └── hester-prynne/
│           ├── default.nix                # the host statement
│           └── autostart-suppression.nix  # host-specific, named in that host's homeImports
├── roles/                        # POLICY — which modules a class of machine, or a job, wants
│   ├── home/
│   │   ├── minimal.nix           # Shell, prompt, bare editor, small local CLI tools
│   │   ├── base.nix              # minimal + git, ssh, gnupg, bins, nvim config
│   │   ├── cli.nix               # base + dev tooling and language runtimes
│   │   ├── gui.nix               # cli + terminal emulators, fonts, desktop apps
│   │   ├── personal.nix          # IDENTITY — portable personal subset; imports personal-claude.nix
│   │   ├── personal-desktop.nix  # personal GUI-desktop add-on; hosts opt in by name
│   │   ├── personal-claude.nix   # personal `programs.claude-code` additions
│   │   └── personal-gh-dash.yml  # personal gh-dash config, symlinked by personal.nix
│   ├── darwin/
│   │   └── personal.nix          # IDENTITY, nix-darwin side — Homebrew taps/brews/casks, the Dock
│   └── nixos/
│       └── base.nix              # Shared base for every Pi host (mainline kernel, ZFS off, stateVersion)
├── modules/                      # MECHANISM — how each tool is configured
│   ├── options.nix               # The `my.*` capability options (both systems)
│   ├── darwin/                   # nix-darwin modules (homebrew, launch-agents)
│   ├── nixos/                    # NixOS modules (gpg-yubikey — hub and airgap import it)
│   └── home/                     # home-manager modules
│       ├── nvim/                 # Neovim configuration
│       ├── tmux/                 # Tmux configuration
│       ├── git/                  # Git configuration
│       └── [tool]/               # Other tool configurations
├── templates/                    # Configuration templates
└── .claude/                      # Claude AI memory files
```

### Adding a home-manager module

`modules/home/<tool>/` defines *how* a tool is configured and says nothing about who wants it. A module is not live until a role imports it — add it to exactly one of `roles/home/{minimal,base,cli,gui}.nix`, which stack (`gui` → `cli` → `base` → `minimal`). Every current machine takes `gui`, so anything added there reaches all of them. Pick the *lowest* tier that is honest: `minimal` is the floor and must stay safe on an airgapped, memory-constrained host, so nothing there may assume a network, a remote, or a `~/dotfiles` checkout. See `CONVENTIONS.md` for the per-tier table and the "compose downward, don't subtract" rule. The `personal*` files in the same directory are *identity* roles, not tiers — they don't stack, and a module belongs there only if one job wants it rather than a class of machine (see "Identity roles live in `roles/`" below).

Divergence follows a three-way rule:

| Kind | Mechanism |
| --- | --- |
| Platform truth | `pkgs.stdenv.isDarwin` / `isLinux` |
| Capability | a `my.*` option in `modules/options.nix` |
| Identity (work vs personal) | an import — the `personal*` role files in `roles/` (work: files directly under `hosts/darwin/fw-skyler/`), named in a host's `homeImports`/`darwinImports` |

Do **not** reach for `pkgs.stdenv.isLinux` to mean "has a GUI" — that only reads correctly while the sole Linux host happens to be a desktop. Use `config.my.gui`.

### Adding a package override or patch: `overlays/`

Package-level overrides (pin a version, patch a `.desktop` file, override a build flag) go in `overlays/<name>.nix`, one overlay function per file — not inside a home-manager module's `nixpkgs.overlays`. Setting `nixpkgs.overlays`/`nixpkgs.config` from inside a home-manager module is a no-op (or an error, on newer home-manager) once a host sets `home-manager.useGlobalPkgs = true`, since there's no separate pkgs left for the module to configure.

**Overlays are named on the host file, like its import lists — opt-in per host, not blanket.** Each `hosts/{darwin,home}/<hostname>` can set `overlays = [(import ../../overlays/<name>.nix) ...];` alongside its `{username, system, homeImports}`; a host that doesn't need an overlay simply omits the field (`host.overlays or []` in `lib/{darwin,home}.nix`). `hosts/home/hester-prynne/default.nix` takes `protonmail-desktop.nix` (the package only ever appears in that host's Linux-only list); `hosts/darwin/fw-skyler/default.nix` takes `pnpm-pin.nix` (the pin is for a work-only monorepo). `lyra-silvertongue.nix` takes neither. `mkDarwinHost`/`mkHomeHost` read the host's `overlays` list, append it to `flake.nix`'s `baseOverlays` (the small universal set — see `CONVENTIONS.md`'s Overlays section), and pass the result through `mkDarwinConfig`/`mkHomeManagerConfig` to wherever that config's pkgs is actually built (`system/darwin.nix`'s nix-darwin-level `nixpkgs.overlays` for Darwin — both hosts run `home-manager.useGlobalPkgs = true`, so home-manager shares that pkgs automatically; `lib/home.nix`'s `mkHomeManagerConfig` builds `pkgs` directly for the standalone Linux host).

### Never make a private, auth-requiring repo a flake input

**Stock Nix fetches every locked flake input eagerly, before it knows which outputs actually use them.** So an input whose fetch needs credentials — a `git+ssh://` private repo — makes *every* host authenticate just to evaluate, including hosts that never reference it. Gating the consumer behind `lib.mkIf`, a `my.*` option, or a role import does not help; the fetch happens before any of that is reached.

This is easy to miss on the desktops, which run Determinate Nix with lazy trees and therefore skip unused inputs. The Pi hosts run stock Nix and do not. It is what made `make hub-switch` fail on `private-assets` — a font repo `hub` never reads, since `modules/home/fonts` is only imported by `roles/home/gui.nix` and `hub` takes `cli.nix`.

**Fetch it in the module that consumes it instead**, with `builtins.fetchGit` pinned to an explicit `rev` (`modules/home/fonts/default.nix` is the worked example). That makes the fetch a thunk only the importing hosts force. Use `builtins.fetchGit`, not a fixed-output `pkgs.fetchgit`: the former runs in the evaluator as the invoking user and can reach the agent holding the Yubikey, while an FOD builds as `nixbld` and has no SSH access at all. A pinned rev resolves offline from `~/.cache/nix/gitv3`, so this costs an authentication only on a cold cache, not per rebuild.

The tradeoff is that `nix flake update` no longer manages the pin. Worth it while the private repo is near-static; see `PRIVATE-ASSETS.md` for when to reverse the decision.

### Identity roles live in `roles/`

There is no `profile` argument and no `users/`. An identity is just **another role file**, sitting flat in `roles/` next to the stacking tier roles, and a host names it directly:

| File | Sets |
| --- | --- |
| `roles/home/personal.nix` | home-manager options: the portable personal subset — gh-dash config, syncthing, identity-only module imports safe on any machine doing that job, headless or not |
| `roles/home/personal-desktop.nix` | the GUI-desktop add-on to the above — keepassxc, orca-slicer, `go`/`hugo` |
| `roles/home/personal-claude.nix` | `programs.claude-code` additions, imported by `personal.nix` |
| `roles/darwin/personal.nix` | nix-darwin options: Homebrew taps/brews/casks, launch agents, the Dock |

Two module systems, so two directories and two lists: a home-manager module cannot set `homebrew.casks`, which is why `roles/darwin/` exists alongside `roles/home/` and a host splits its imports into `homeImports` and `darwinImports`.

**Identity role files sit flat beside the tier roles, not in a subdirectory of their own.** `roles/home/` holds `minimal.nix`/`base.nix`/`cli.nix`/`gui.nix` *and* the `personal*` files side by side; the `personal-` filename prefix is the grouping. This is deliberate — nesting them would reintroduce the very layer that was removed.

**A host states one ordered `homeImports` list, and nothing gets spliced onto it.** `hosts/{darwin,home}/<name>` states `{username, system, homeImports, darwinImports ? [], overlays ? []}`. There is no `user` path field, no `user + "/home.nix"` filename contract, and no separate `extraHomeImports`: `lib/darwin.nix` and `lib/home.nix` read the lists and pass them through verbatim (`system/darwin.nix` puts `homeImports` on `home-manager.users.<username>.imports` and splices `darwinImports` into the nix-darwin module list). Because the tier role is no longer hardcoded in `flake.nix`, a host names its own: `lyra-silvertongue`, `fw-skyler`, and `hester-prynne` each open their `homeImports` with `roles/home/gui.nix` and then add what else they want.

**`work` has only one machine, so it has no `roles/` file at all — it lives directly on its host.** `hosts/darwin/fw-skyler/` holds `home.nix`/`darwin.nix`/`claude.nix`/`gh-dash.yml`/the work Yubikey public key, and the host's own `default.nix` names `./home.nix` in `homeImports` and `./darwin.nix` in `darwinImports`. A `roles/` file only earns its keep once two or more hosts share it — `personal` does (the personal Mac and the Linux desktop), so it lives in `roles/`.

**A module that only one identity wants is imported from that identity's role file (or its GUI-only `personal-desktop.nix`, see below), not from a tier role.** `keepassxc` and `orca-slicer` work this way; putting them in `roles/home/gui.nix` would mean gating them back off. Tier roles carry what a *class of machine* wants; identity roles carry what a *job* wants.

**Split an identity role into a portable base plus opt-in add-ons once it needs to reach a headless host.** `roles/home/personal.nix` is the portable subset (personal-claude.nix, gh-dash, syncthing) — safe for a future headless personal Pi. The GUI-desktop-only pieces (keepassxc, orca-slicer, `go`/`hugo`) live in `roles/home/personal-desktop.nix` instead, and a host opts into it by naming that file in its own `homeImports`. Both current personal hosts (`lyra-silvertongue`, `hester-prynne`) do; a future headless personal Pi would take `personal.nix` without it. Don't fold `personal-desktop.nix` back into `personal.nix` — that's exactly the coupling this split removes.

Most options merge, so a role file **adds** to a module rather than replacing it — `home.packages` and `homebrew.casks` are `listOf` (concatenate), `launchd.user.agents` is an attrset of submodules (merges).

**When a list won't concatenate, use base-default + host-replacement.** Freeform `types.anything` options (`programs.ssh.settings` is the one in this repo) *throw* on two list definitions rather than concatenating, so a role (or host) cannot append. Don't respond by moving the whole value into the role/host files — state the common case in the module as a `lib.mkDefault` and let the one that needs something else replace it:

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

Role/host ordering in merged lists is not stable — `roles/` and `hosts/` definitions may land before or after a module's. Nothing currently depends on it (Homebrew installs a set; `permissions.allow` matches by any-match), but do not introduce anything that does.

## Management Commands

- **Rebuild and switch:** `make rebuild` — auto-detects Darwin vs Linux and picks the flake attribute from the machine's hostname (`hostname -s`). **Darwin and `hester-prynne` only:** its Linux branch takes the standalone home-manager path, so on a NixOS host it fails with `does not provide attribute homeConfigurations."<host>"`. Use `make hub-switch` on the hub — see "NixOS Pi Hosts" below.
- **Host selection:** flake outputs are keyed by hostname (`fw-skyler`, `lyra-silvertongue`, `hester-prynne`). Each `hosts/{darwin,home}/<hostname>` states `{username, system, homeImports, darwinImports ? [], overlays ? []}`; `homeImports` is one ordered list naming the tier role plus any identity or host-specific modules, and `darwinImports` is its nix-darwin counterpart (see "Identity roles live in `roles/`" below).

### Pin every Darwin host's hostname

macOS keeps three separate names, and only one of them is what `hostname` returns:

| Name | Read with | Role |
| --- | --- | --- |
| `ComputerName` | `scutil --get ComputerName` | The friendly name in System Settings and AirDrop |
| `LocalHostName` | `scutil --get LocalHostName` | The Bonjour `.local` name |
| `HostName` | `scutil --get HostName` | Sets `kern.hostname` — **this is what `hostname` reports** |

**When `HostName` is unset, configd derives `kern.hostname` from the network** — DHCP option 12 or reverse DNS of the current lease — and only falls back to `LocalHostName` if the network offers nothing. So a router or VPN can silently rename the machine out from under `make rebuild`, whose `host="$(hostname -s)"` then names a flake attribute that does not exist:

```
error: flake '...' does not provide attribute 'darwinConfigurations.Mac.system'
```

Verified 2026-08-11 on `fw-skyler`: `ComputerName` and `LocalHostName` were both still `fw-skyler`, `HostName` was **not set**, and `kern.hostname` had become `Mac`. Because System Settings shows `ComputerName`, the machine looks correctly named while `hostname` disagrees — do not use System Settings to check this.

**So every Darwin host sets `networking.hostName`, and its value must equal that host's `darwinConfigurations` attribute name.** nix-darwin runs `scutil --set HostName` on activation, which pins `kern.hostname` against DHCP. `networking.localHostName` defaults to `networking.hostName`, so the one line pins both; setting `localHostName` alone fixes nothing, because `HostName` is still unset and still network-derived.

Set it on the **host**, never in a `roles/` file — the name identifies one machine, not a class or an identity. `fw-skyler` sets it in its own `darwin.nix`; `lyra-silvertongue` has no host-level darwin file, so it carries an inline `{networking.hostName = ...;}` module in its `darwinImports`.

Leave `networking.computerName` alone unless you intend to rename the machine everywhere it is user-visible.

The chicken-and-egg case — a machine whose `HostName` is unset cannot `make rebuild` to acquire the pin — is broken by hand, once:

```bash
sudo scutil --set HostName <attr-name>
```

The three Pi hosts already set `networking.hostName` in their `configuration.nix`. `hester-prynne` is standalone home-manager with no NixOS module, so it has nothing to set this from and depends on the OS being named correctly.

### macOS GUI apps: `copyApps` is off on purpose

**Do not re-enable `targets.darwin.copyApps.enable`, and do not add a GUI `.app` to `home.packages` on a Mac.** Its activation step probes for the App Management permission by running `tccutil reset SystemPolicyAppBundles`, which wipes every App Management grant on the machine and can abort the rebuild. A `/nix/store` process has no code-signing identifier, so TCC reads it as `InvalidCode` and will not prompt; only Terminal.app carries the private entitlement that makes prompting work, and granting Ghostty the permission explicitly has been confirmed not to help. `roles/home/gui.nix` sets it to `false` for this reason — see `README.md` for the full rationale, including why GUI apps stay on Homebrew casks.

Note that `home.stateVersion = "26.05"` in `roles/home/minimal.nix` is inherited by every host, and 26.05 ≥ 25.11 is exactly where `copyApps` defaults on — so this is armed by default, not opt-in. It stayed inert only because no Darwin `home.packages` entry currently ships an `.app` for the rsync glob to match.

The old `~/Applications` Spotlight complaint is obsolete and should not be repeated in new docs. Since late 2025 nix-darwin copies to `/Applications/Nix Apps` (PR #1396) and home-manager to `~/Applications/Home Manager Apps` (PR #8031) as real files rather than symlinks, and real copies **are** indexed. Symlinks still are not — macOS did not change, the deployment mechanism did.

On macOS 26, Launchpad no longer exists as a separate app; it is an Apps pane inside Spotlight. Instructions that say "check Launchpad" are stale.

## NixOS Pi Hosts

Three `nixosConfigurations` live in `hosts/nixos/`, all `aarch64-linux`: `hub` (the always-on Pi 4, general building hub), `airgap` (the airgapped Yubikey Pi Zero 2W), and `uptime` (the uptime-kuma Pi Zero 2W). Each is a **directory** — `default.nix` states the host, `configuration.nix` is that machine's own NixOS module. `hosts/nixos/` contains nothing else; the two things every Pi shares moved to their taxonomy layers: `roles/nixos/base.nix` (policy — imported by all three) and `modules/nixos/gpg-yubikey.nix` (mechanism — imported by `hub` and `airgap` only).

| Task | Command | Run from |
| --- | --- | --- |
| Build the airgap Zero image | `make airgap-image` | hub |
| Build the uptime image | `make uptime-image` | hub |
| Deploy to the uptime Zero | `make uptime-switch` (override `UPTIME_HOST`) | hub |
| Rebuild the hub itself | `make hub-switch` | hub |

### A Pi host states the same kind of attrset the Macs do

`hosts/nixos/<name>/default.nix` states `{system, nixosImports, username ? null, homeImports ? []}`, and `flake.nix` instantiates it with a single `mkNixosHost ./hosts/nixos/<name>` — no positional arguments, matching `mkDarwinHost`/`mkHomeHost`. `nixosImports` carries that machine's `./configuration.nix` plus whichever `roles/nixos/` and `modules/nixos/` files it wants, and `homeImports` names the tier role directly: `lib/nixos.nix` no longer hardcodes `roles/home/cli.nix`, exactly as `flake.nix` stopped hardcoding `roles/home/gui.nix` for the Macs. A host declares what it is.

Home-manager status per Pi — a decided question, not a pending one:

| Host | home-manager | Notes |
| --- | --- | --- |
| `hub` | yes, user `skyler` | `homeImports = [roles/home/cli.nix]` — `cli`, not `gui`: headless board with a real login |
| `airgap` | no, deliberately and permanently | an air-gapped single-purpose Yubikey appliance; `environment.systemPackages` in `roles/nixos/base.nix` covers everything it needs |
| `uptime` | yes, user `uptime` | `homeImports = [roles/home/minimal.nix]` — `minimal`, not `cli`: 512MB Zero 2W whose job is uptime-kuma. The home-manager exists so SSHing in to read logs is not hostile, not so the box can develop anything |

`uptime`'s home-manager user is the `users.users.uptime` SSH-administration account from its `configuration.nix`; uptime-kuma itself runs under the upstream module's `DynamicUser` and has no home. Note that `roles/home/minimal.nix` and `roles/nixos/base.nix` both bring in `neovim` — verified to be the same store path, so it is not paid for twice.

**A host that omits `username` gets no `nixpkgs.overlays` and no `nixpkgs.config.allowUnfree` either.** `lib/nixos.nix` sets both *inside* the `username != null` branch. That is intentional, not an oversight — it is what `airgap` has always evaluated to, and hoisting them out would silently change its closure.

### Never import nixos-hardware into an sd-image host

`nixos-hardware`'s `raspberry-pi-*` modules `mkForce`-replace `populateFirmwareCommands` from `sd-image-aarch64.nix`. Their replacement only installs `u-boot.bin` (and the matching `kernel=` / `arm_64bit=1` lines in `config.txt`) when `hardware.raspberry-pi.firmware.uboot.enable` is set. Left off, the firmware partition gets `bootcode.bin`/`start.elf`/dtbs but **no kernel**, so the GPU firmware has nothing to hand off to and the board dies with **7 LED flashes**.

Enabling `uboot` papers over it; dropping `nixos-hardware` is the actual fix, and also removes the need to re-set `hardware.raspberry-pi.configtxt.settings.pi02.core_freq = 250` to keep serial output from garbling. So an image-built host imports **stock `sd-image-aarch64.nix` and nothing else**.

`hosts/nixos/hub/configuration.nix` is the exception and is correct as written: it is installed in place and rebuilt with `nixos-rebuild switch`, so the sd-image module is never in play. Do not "fix" the asymmetry, and do not use it as the template for a new image-built host.

`roles/nixos/base.nix` also sets `boot.supportedFilesystems.zfs = lib.mkForce false`. This is load-bearing, not cosmetic — the sd-image default pulls ZFS in and it will not build for the aarch64 image.

### A Pi Zero cannot rebuild itself

A Zero 2W has 512MB of RAM. *Evaluating* a NixOS closure peaks well above that before any compilation starts, so an on-device `nixos-rebuild` means swapping onto the SD card for a very long time. Deploy instead: `make uptime-switch` runs on the hub, which evaluates and builds natively for aarch64 and pushes only the resulting closure. The Zero just activates it. The dotfiles clone on the Zero is for reading and editing config, not for rebuilding.

### Secrets on the uptime host

Nothing about the Cloudflare tunnel is in this repo. `hosts/nixos/uptime/configuration.nix` runs a hand-rolled `cloudflared-tunnel` unit rather than `services.cloudflared`, because that module takes the tunnel UUID as an attribute name and renders ingress rules into a store-built `config.yml` — both eval-time inputs, and both things that would end up published in this repo.

Seed the host by placing two files in `/etc/cloudflared`, either on the mounted image before flashing or over SSH afterwards:

- `config.yml` — tunnel UUID, `credentials-file: /etc/cloudflared/credentials.json`, and an ingress rule pointing the public hostname at `http://127.0.0.1:3001`
- `credentials.json` — from `cloudflared tunnel create`

`systemd.tmpfiles` `z` rules re-apply `root:cloudflared` `0640` to both on every boot, so seeding them on a build machine where the `cloudflared` uid does not exist yet still works. Until `config.yml` exists the unit's `ConditionPathExists` keeps it inert instead of crash-looping.

## Claude Code Nix Module

The Claude Code configuration is Nix-managed in `modules/home/claude/`. The global `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, hooks, skills, agents, and commands are all deployed from this repo into the Nix store.

### How to make changes

| Change             | Where to edit                                                                       | Then run                                   |
| ------------------ | ----------------------------------------------------------------------------------- | ------------------------------------------ |
| Add MCP server     | `hosts/darwin/fw-skyler/claude.nix` or `roles/home/personal-claude.nix`                 | `make rebuild`                             |
| Add hook           | Create script in `modules/home/claude/config/hooks/`, add to `default.nix` settings   | Rebuild                                    |
| Add skill          | Add to `modules/home/claude/config/skills/`                                           | Stage it (the user's action — Claude is denied `git add`), then rebuild — see Permissions below |
| Add agent          | Add to `modules/home/claude/config/agents/`                                           | Rebuild                                    |
| Change plugin      | Edit `enabledPlugins` in `modules/home/claude/default.nix`                            | Rebuild                                    |
| Change permissions | Edit `permissions` in `modules/home/claude/default.nix` (base), `hosts/darwin/fw-skyler/claude.nix` (work), or `roles/home/personal-claude.nix` (personal) | Rebuild |
| Change setting     | Edit `modules/home/claude/default.nix` (base), `hosts/darwin/fw-skyler/claude.nix` (work), or `roles/home/personal-claude.nix` (personal) | Rebuild |

### Deployment Layout

`agents/`, `commands/`, `hooks/`, `skills/`, and `CLAUDE.md` are deployed by the home-manager module's own options (`agentsDir`, `commandsDir`, `hooksDir`, `skills`, `context`) rather than hand-wired `home.file` entries. Only `RTK.md` and `statusline.sh`, which have no matching option, are still declared in `home.file`.

Everything under `~/.claude` is therefore a symlink into the Nix store, and **every edit under `config/` needs a rebuild to take effect** — including hook scripts. The `*Dir` options have no `mkOutOfStoreSymlink` escape hatch, so they don't honor `my.dotfiles.mutable`; that's the accepted cost of the module being usable on a NixOS host with no `~/dotfiles` checkout.

The `*Dir` options and the path form of `skills` deploy with `recursive = true` — set inside the module's own `mkRecursiveDirAttrs`, not by anything this repo passes. That makes home-manager create `~/.claude/<subdir>` as a real directory and link each child individually, instead of pointing the whole subdirectory at one store path. Enumerating skills one-by-one used to be the workaround and is no longer needed. That per-file layout is also what makes the migration hazard below possible, so it is worth knowing which shape is deployed.

**The MCP plugin does not land in `~/.claude/skills/`.** The pinned home-manager (`flake.lock` rev `d4fd2466`) builds it as a store directory named `claude-code-hm-plugin` and hands it to a wrapper script as `--plugin-dir`, unconditionally — so `~/.claude/skills/` holds exactly the repo's own skills and nothing else. Newer home-manager revisions add a "personal plugins" mode that installs to `~/.claude/skills/<plugin>` when claude-code is ≥ 2.1.157, and gate `recursive = true` on avoiding a collision with it; none of that code is in the pinned revision, so do not reason from it. Several home-manager sources coexist in `/nix/store` — confirm the one you are reading matches `flake.lock` before drawing conclusions from it.

### Migrating a directory off `mkOutOfStoreSymlink`

**Delete the old live symlinks by hand before the first rebuild after such a change.** Switching a directory from `mkOutOfStoreSymlink` to a store-backed per-file layout — what commit `cd210a1` did for `agents/`, `commands/`, `hooks/`, and `skills/` — does not retire the symlink the previous generation already placed in `~`. That link resolves *through* the store and back into the working tree:

```
~/.claude/agents
  -> /nix/store/<gen>-home-manager-files/.claude/agents
  -> /nix/store/<hash>-hm_agents                     # mkOutOfStoreSymlink: a store symlink...
  -> ~/dotfiles/modules/home/claude/config/agents    # ...whose target is the repo
```

home-manager then creates each new per-file entry *through* that chain, so `ln -s … ~/.claude/agents/foo.md` lands in `~/dotfiles/…` instead. The tracked source is moved aside to `foo.md.hm-backup` and replaced by a store symlink, and `git status` reports the whole tree as typechanged (` T`). Restoring from git alone does not hold — the next rebuild repeats it, because the chain is what is broken, not the files. The `.hm-backup` files are a symptom, never the cause.

Home-manager will not clear the stale links itself. It retires orphans by diffing against the previous generation it holds a pointer to, and under nix-darwin those pointers diverge (verified 2026-08-11: the gcroot, the home-manager profile, and the live files each named a different generation), so the old `.claude/agents` entry is never seen as an orphan.

Fix in this order; the order is load-bearing:

1. `rm ~/.claude/agents ~/.claude/commands ~/.claude/hooks ~/.claude/skills/*` — every one is a symlink, so flagless `rm` suffices. Do **not** use `rm -rf`, and never add a trailing slash: `rm -rf ~/.claude/agents/` deletes the repo directory the link resolves to. Flagless `rm` also avoids `Bash(rm -rf *)` in `permissions.deny`, which refuses the `-rf` form when run through Claude Code.
2. `git checkout -- modules/home/claude/config/`, then delete the `*.hm-backup` files — before rebuilding. A rebuild while the sources are still symlinks copies the *symlinks* into the new store path rather than the content, stacking another layer of indirection each time.
3. Quit all sessions, then `make rebuild`.

Verify with:

```bash
find ~/.claude -maxdepth 2 -type l -exec sh -c 'readlink -f "$1" | grep -q "^$HOME/dotfiles/" && echo "$1"' _ {} \;
```

It must print nothing, `~/.claude/{agents,commands,hooks,skills}` must be real directories, and every link under `~/.claude` must name a single generation.

### Quit Claude sessions before rebuilding

**`make rebuild` while a Claude Code session is running deletes `~/.claude/settings.json`.** Quit all sessions first, rebuild, then restart them.

`make rebuild` refuses to run when it detects a live session, listing each one so you know what to quit. `make claude-sessions` shows the same list on its own. Override with `make rebuild FORCE=1` when you accept the loss.

**Do not detect sessions with `pgrep -x claude` — it matches nothing, and the gate built on it passed silently for every rebuild until 2026-08-10.** The package is a Nix binary wrapper: `bin/claude` is a compiled stub that `execve`s `.claude-wrapped` in place, so the surviving process's `comm` reads `.claude-wrapped` and never `claude`. `-x` matches `comm`, so it always comes back empty. argv[0] *is* still `claude`, which is why `pgrep -af claude` lists the session and makes the failure look like something else. Verified on hester-prynne with `/bin/pgrep` (absolute path, so no shell rewriting involved): `pgrep -x claude` exited 1 while `ps -o comm=` on the live PID printed `.claude-wrapped`.

An earlier version of this section blamed the empty result on `pgrep` "missing the invoking process" and advised running from a plain terminal. That was wrong — `pgrep` excludes only itself, never its ancestors, and a rebuild launched from a separate tmux window failed to fire just the same. The advice actively hid the bug.

`make rebuild` uses the `CLAUDE_PIDS` variable in the `Makefile` instead, matching either name on the basename (macOS `ps` reports `comm` as a full path). It is deliberately `ps`/`awk` only: `procps` is not declared anywhere in this config, and a missing `pgrep` made the old gate fail *open* — `pgrep … 2>/dev/null` swallows "command not found" and the `&&` short-circuits to "no sessions running."

The home-manager `claude-code` module deploys settings.json as a symlink to a store file installed `-Dm444` (`modules/programs/claude-code/default.nix`), so it is read-only. When a rebuild swaps that symlink to a new generation with different content, a *running* Claude Code process notices the change a few minutes later and tries to write the file back; it cannot write the read-only target in place, so it unlinks first and the write never lands. The symlink is simply gone, and with it every permission rule — so everything starts prompting, silently.

Verified 2026-07-28 on claude-code 2.1.220, five trials: three rebuilds with a session running all lost the file within ~5 minutes; a rebuild with no session running kept it; and manually relinking to the *same* store target (no content change) survived 21 minutes. So the trigger is a content change observed by a live process, not the rebuild alone.

**To recover: quit all sessions and re-run `make rebuild`.** Then confirm with `jq '.permissions.allow | length' ~/.claude/settings.json` — the failure mode is a missing file, not a malformed one, so any successful `jq` read means it is back.

Do not try to reconstruct the symlink from the home-manager profile paths. Under nix-darwin they diverge: verified 2026-07-28, `~/.local/state/nix/profiles/home-manager/home-files/` had no `.claude/settings.json` at all, `~/.local/state/home-manager/gcroots/current-home/` pointed at a stale generation, and the live symlink pointed at a third — because home-manager runs as a nix-darwin module, so the authoritative `home-manager-files` derivation is referenced from the system generation rather than the home-manager profile. If you must relink by hand, take the target from `readlink ~/.claude/settings.json` *before* it disappears.

### A repo's `settings.local.json` silently overrides the Nix config

`<repo>/.claude/settings.local.json` takes precedence over the Nix-managed `~/.claude/settings.json`, and the `/sandbox` panel **writes to it**. Selecting a sandbox mode there persists `sandbox.enabled` per-repo, where it outranks the module.

This had the sandbox fully disabled in this repo — for long enough that its absence read as a Claude Code bug — while `sandbox.enabled = true` was correctly deployed in `settings.json`. The symptom is that sandbox settings look right and nothing enforces: no proxy env vars, `curl` reaching non-allowlisted hosts, `denyRead` paths readable.

**Check `.claude/settings.local.json` before concluding a settings-level feature is broken.** The file is gitignored, so this is per-machine state — fixing it in one checkout fixes nothing elsewhere. Note also that a failed sandbox startup degrades to *no sandbox* with only a warning; `sandbox.failIfUnavailable = true` makes that a hard failure instead.

### Settings Merge Behavior

- `programs.claude-code.settings` uses a freeform JSON type (`pkgs.formats.json`) — do **not** wrap the entire attrset with `lib.mkDefault` (it prevents merging; see Architecture section above)
- Base settings in `default.nix` are set without `mkDefault`; the JSON type merges attrsets across definitions automatically
- Identity settings live in `roles/home/personal-claude.nix` or (for work) `hosts/darwin/fw-skyler/claude.nix`, and are **not** gated — the file is only imported by the machine that wants it, so no `lib.mkIf` is involved
- For individual leaf values that an identity role needs to override, apply `lib.mkDefault` to that specific value in `default.nix`
- List-valued settings (`permissions.allow`, `sandbox.filesystem.allowRead`) concatenate across the two files, but **the resulting order is not guaranteed** — identity entries may precede or follow the base ones. Fine for allow-matching; do not add anything order-sensitive. Hook arrays are order-sensitive and are defined only in `default.nix` for this reason.

### MCP Servers

MCP servers are declared in `roles/home/personal-claude.nix` or `hosts/darwin/fw-skyler/claude.nix` under `programs.claude-code.mcpServers`. The home-manager module writes these to `~/.claude.json` and they appear as `plugin:claude-code-home-manager:<name>`.

MCP servers with OAuth (e.g., Asana) require a two-part setup:

1. **Config (Nix-managed):** Add the server to the `mcpServers` attrset in the relevant `claude.nix`. This gets deployed via `make rebuild`.

2. **Auth (manual, one-time):** Run the following command to store OAuth credentials in the macOS Keychain. This only needs to be done once per machine (survives Nix rebuilds).

```bash
claude mcp add --transport http \
  --client-id "$ASANA_CLIENT_ID" \
  --client-secret \
  --callback-port 8080 \
  asana https://mcp.asana.com/v2/mcp
```

### Permissions

Claude Code permissions live in `modules/home/claude/default.nix` (base) with additions in `roles/home/personal-claude.nix` or `hosts/darwin/fw-skyler/claude.nix`. Three coordinated layers:

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

#### Pattern scope — `**/` is project-relative

A `Read(**/x)` rule matches only under the current project root, **not** the whole filesystem. Verified 2026-08-11 against the live `Read(**/.npmrc)` rule: a dummy `.npmrc` inside the repo was denied; the same file under `/private/tmp` was read successfully. Per the Claude docs, Read/Edit rules use `//path` for absolute and `/path` for project-relative — a different convention from `sandbox.filesystem.*` paths, which use standard prefixes (`/`, `~/`, `./`).

So `Read(**/.env)` guards the `.env` of whatever project Claude is working in and nothing wider. That is a bounded guarantee — do not write such a rule and then describe it as blanket coverage. Whether globs work in `sandbox.filesystem.denyRead` at all is undocumented and untested.

#### Condensing MCP allowlists

MCP tools typically share verb prefixes: `get_`, `list_`, `search_`, `find_`, `whoami` (read) vs. `create_`, `delete_`, `edit_`, `update_`, `add_`, `remove_`, `move_`, `import_`, `rename_`, `toggle_`, `acknowledge_`, `escalate_`, `resolve_`, `reopen_` (write). Use glob patterns on the read-only verb prefixes (e.g., `mcp__asana__get_*`, `mcp__asana__search_*`) instead of enumerating each tool — mutating tools won't match because their verbs are different.

When verb prefixes are mixed (e.g., Expo's `build_info` is read but `build_run` is write), use suffix globs like `*_info`, `*_list`, `*_logs` to capture the read shape without catching writes.

#### Defense-in-depth for broad allows

`Bash(gh api*)` is allowlisted broadly because the deny list blocks every write verb (`-X POST/PATCH/PUT/DELETE`, `-f`, `--field`). Pattern: broad allow on the read surface + targeted denies on the write verbs. Deny wins, so the broad allow is safe.

#### Custom skills and commands — **important**

Custom skills (in `modules/home/claude/config/skills/`) and custom slash commands (in `modules/home/claude/config/commands/`) both have no plugin namespace, so they can't be matched by a wildcard. They also share the same permission gate — `/<name>` invokes the Skill tool whether the underlying file is a `SKILL.md` or a command `.md`.

**Do not add a `Skill(<name>)` entry by hand — it is derived.** `default.nix` builds `skillNames` from `readDir ./config/skills` plus the `.md` files in `./config/commands`, and maps each to `Skill(<name>)` onto `permissions.allow`. A hand-written entry is a duplicate on arrival. Two things are still required:

- **`git add` the new file or directory.** `skillNames` reads the *flake source*, and flakes only see git-tracked files — an untracked skill directory is invisible to eval, so no permission entry is generated and it prompts on first use. Verified 2026-08-10: `Skill(comment-review)` was absent from the derived allowlist until the directory was staged, then appeared immediately.
- **Rebuild.** The names are read at eval time, so a new skill needs a rebuild to register (and to be symlinked).

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
- **Identity by import** - Personal/work divergence is a role file a host names, never a conditional on a profile string
- **Declarative** - All configurations are explicitly defined
- **Version controlled** - Everything is tracked in git
- **Reproducible** - Configurations can be applied to new machines

## Key Features

- **Automatic tool installation** via Nix packages and Homebrew
- **Shared mechanism, per-host policy** — modules state how a tool works; roles and hosts state who wants it
- **Integrated development environment** with LSP, formatting, linting
- **Custom keybindings** and shortcuts across all tools
- **Backup and sync** via git repository

## Getting Started

1. Clone repository
2. Review the host entry for this machine under `hosts/` — it names the tier role, any identity roles, and overlays
3. Run `make rebuild` to apply configurations
4. Customize individual modules as needed

## Maintenance Notes

- **Regular updates:** Keep flake.lock updated
- **Cross-host testing:** A change to a shared module reaches every host that imports it — check the affected hosts, not just this machine
- **Documentation:** Update memory files when patterns change
- **Backup:** Configurations are version controlled but consider additional backups for sensitive data

