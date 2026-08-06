# Nix Configuration Conventions

This is the durable architectural reference for how `nix/` is organized — the
rules that should still hold after any given migration step is long done.
It is distinct from two other documents:

- **`CLAUDE.md`** — directives for how Claude Code should behave in this repo
  (commands, permissions, communication rules). It also documents some of the
  same architecture inline; this file is the place to consult (or extend)
  when a structural question comes up, rather than duplicating the answer in
  both places.
- **`docs/local/plans/nix-architecture-redesign.md`** — the migration log for
  the ongoing restructure: step-by-step history, verification records, what
  landed and why. Gitignored, not committed. Read it for *how a past decision
  was reached*; read this file for *what the current rule is*.

(A later step is expected to eliminate `nix/` as a middle layer — flake.nix
and everything under it moving up to the repo root. This file lives at the
root, not under `nix/`, so it survives that move unchanged.)

---

## The three-way rule

Every piece of divergence between hosts falls into exactly one of three
buckets. Before adding a new conditional or option, identify which one you're
looking at — the mechanism follows directly:

| Kind | Question | Mechanism |
|---|---|---|
| **Platform truth** | Is this a fact about the OS/architecture itself? | `pkgs.stdenv.isDarwin` / `isLinux`, inline |
| **Capability** | Does a *class* of machine have or lack some property? | a `my.*` option in `nix/modules/options.nix` |
| **Identity** | Does only *this job/host* want this at all? | an import — an identity role file (`nix/roles/home/personal*.nix`, `nix/roles/darwin/personal.nix`), `nix/hosts/<host>/`, or a tier role file |

**Platform truth is legitimate to leave inline**, including inside a shared
module — `gnupg`'s pinentry selection (`isDarwin` → `pinentry-mac`), `rtk`'s
config path (`isDarwin` → Library path, else XDG), `firefox`'s
`package = null` on Darwin (Homebrew owns it there) are all correct as
written. Don't "fix" these into options or imports; they're facts, not
decisions.

**Capability and identity are the ones that get confused, and the confusion
is the recurring bug.** `pkgs.stdenv.isLinux` is not "has a GUI" — it just
happens to read that way while every current Linux host is a desktop. When
that stops being true (a headless Pi), packages gated on `isLinux` alone leak
onto it. The fix is never "add more `isLinux` special-casing" — it's
identifying which of the other two buckets the divergence actually belongs
to:

- If it's "any machine with a GUI wants this" → gate on `config.my.gui`
  (capability).
- If it's "only this one host/persona wants this" → make it an import instead
  of a conditional at all (identity). A module that's *only ever imported*
  from `roles/home/gui.nix` (`aerospace`, `karabiner`, `alacritty`,
  `linux-gui-pkgs.nix`) can then safely self-gate on pure platform truth
  internally, because the capability gate already happened at the import
  site — that's not a contradiction of the rule above, it's the two
  mechanisms composing correctly.

A host-specific block (hardware quirks, one machine's autostart suppression)
that lives in a shared module because "there's nowhere else for it yet" is a
signal the identity axis is missing a home, not a reason to gate it on
platform truth. Give it a `hosts/<name>/` file and import it from there,
unconditionally.

## The three-layer taxonomy

| Layer | Says | Example |
|---|---|---|
| `nix/modules/` | *how* a tool is configured — mechanism | `modules/home/nvim/` sets up Neovim; says nothing about who wants it |
| `nix/roles/` | *which class of machine, or which job,* wants a set of modules — policy | `roles/home/gui.nix` imports every GUI-desktop module and stacks onto `cli.nix` → `base.nix`; `roles/home/personal.nix` and `roles/darwin/personal.nix` carry the personal job |
| `nix/hosts/` | *which machine this is* — instantiation | `hosts/darwin/fw-skyler/` — `{username, system, homeImports, darwinImports ? [], overlays ? []}`, plus that machine's own host-specific files |

> **`nix/users/` has been dissolved into `nix/roles/`.** Work-vs-personal is
> not two people, it's two jobs a machine does — which is a question of what
> gets installed, not of identity. The evidence: `hub` already ran
> home-manager with no persona at all, and `modules/home/git/` has always
> resolved work-vs-personal by `includeIf "gitdir:"` — that is, by
> *checkout*, not by machine. `users/personal/` is gone; its files are now
> `roles/home/personal{,-desktop,-claude}.nix`, `roles/home/personal-gh-dash.yml`,
> and `roles/darwin/personal.nix`. Work never had a persona directory and
> still doesn't — `fw-skyler` is the only work machine, so its files stay
> under `hosts/darwin/fw-skyler/`. See the redesign doc §9.1–9.2.
>
> The one thing that would bring a persona layer back is a second *person*
> (a shared machine, someone else's account). A host file merely getting
> long is not that.

**A host composes itself; nothing is spliced onto it.** `homeImports` is one
ordered list naming a tier role plus whatever identity or host-specific
modules that machine wants, and `darwinImports` is its nix-darwin counterpart
— there is no `user` path field, no filename contract for the flake to build
paths from, and no separate `extraHomeImports`. `nix/lib/{darwin,home}.nix`
pass both lists through verbatim. Because the tier role is named by the host
rather than hardcoded in `flake.nix`, a new host that wants `cli` instead of
`gui` just says so.

**Identity role files sit flat in `roles/home/`, beside the tier roles**, with
a `personal-` filename prefix doing the grouping. Giving them a subdirectory
of their own would reintroduce exactly the layer this dissolution removed.
They do not stack the way the tiers do — a host names the ones it wants.

The tier roles stack (`gui` → `cli` → `base` → `minimal`); a host should name
one tier role plus the identity roles for the job it does, never a long list
of individual modules. If a host file's import list is growing item by item,
that's the signal a role is missing, not a host quirk to carry indefinitely.

| Role | Adds | For |
|---|---|---|
| `minimal` | shell, prompt, bare editor, small local CLI tools | the floor — nothing assuming a network, a remote, or a `~/dotfiles` checkout |
| `base` | git, ssh, gnupg, `bins`, the LazyVim config | a networked machine I log into |
| `cli` | dev tooling, language runtimes, Claude, tmux | a machine that is actually developed on |
| `gui` | terminal emulators, fonts, desktop apps | a machine with a display |

**Compose downward, don't subtract.** A host that needs less than a role
provides takes the tier below it and adds the specific modules it wants — it
does not take the higher tier and remove things. `disabledModules` is built
for replacing a module with a fork, not opting out, and fails
silently-wrong if another role adds the module back by a different path;
per-module `enable` flags would put an options block on every module to serve
one host. If no existing tier is low enough, the answer is a new tier, not a
subtraction mechanism.

A role plus one or two deliberate module imports is legitimate composition
for a host that is permanently a class of one (the airgap Pi wanting `gnupg`
and nothing else networked). The "import list growing item by item" warning
above is about hosts that are instances of a *class* — those want a role.

## `my.*` capability options

Declared in `nix/modules/options.nix`. Deliberately kept small — an option
only earns a place here once a module a host *already imports* needs to
behave differently depending on it. Don't add one speculatively "in case it's
needed later"; add it when the second real consumer shows up.

Some are explicitly **transitional** — `my.dotfiles.mutable` exists only
because out-of-store symlinks haven't been fully retired yet (see
`CLAUDE.md`'s Claude Code section and the redesign doc §6.4). When a
transitional option's reason for existing goes away, delete the option, don't
leave it as dead configuration surface. Check an option's doc comment before
extending its usage — it may say so explicitly.

## Overlays

One overlay function per file in `nix/overlays/`, applied where each config's
`pkgs` is actually constructed (never inside a home-manager module once
`useGlobalPkgs = true` is in play — there's no separate `pkgs` left for it to
configure). Two shapes:

- **Host-scoped** (the common case): a host's own file sets `overlays = [...]`
  and only that host gets it — e.g. `pnpm-pin.nix` (one work monorepo),
  `protonmail-desktop.nix` (one Linux desktop's `.desktop` patch).
- **Universal**: threaded as a `baseOverlays` list applied to every host in
  `flake.nix`, for something every current *and planned* host needs — e.g.
  `claude-code-unstable.nix`, since `programs.claude-code` reaches every host
  via `roles/home/cli.nix`.

Don't default to universal. A host-scoped overlay that turns out to be needed
everywhere should get promoted deliberately, not started broad "to be safe."

## Config drift is expected — audit for it, don't just avoid it going forward

A module written before a convention existed does not retroactively follow
it. `modules/home/pkgs.nix`'s `linuxPkgs` list predated `my.gui` and was never
revisited once that option existed; `roles/home/base.nix`'s autostart-
suppression block predated `hosts/home/` having a real per-host file and
carried a TODO saying so for several steps before anyone acted on it. Neither
was sloppy at the time it was written — the convention it now violates simply
didn't exist yet, and nothing forces a stale module to get rechecked against
a newer one unless something (a new host, a bug report, a deliberate audit)
puts it back in view.

**Practical implication:** when a session's work newly exercises an old,
previously-static module — especially by adding a new *kind* of host, not just
another instance of an existing kind — treat that as a prompt to check the
module against current conventions, not just against whether it evaluates.
"It's always worked" is not the same claim as "it matches the current rule."
