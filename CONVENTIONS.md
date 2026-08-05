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
| **Identity** | Does only *this persona/host* want this at all? | an import — `nix/users/<persona>/`, `nix/hosts/<host>/`, or a role file |

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

## The four-layer taxonomy

| Layer | Says | Example |
|---|---|---|
| `nix/modules/` | *how* a tool is configured — mechanism | `modules/home/nvim/` sets up Neovim; says nothing about who wants it |
| `nix/roles/` | *which class of machine* wants a set of modules — policy | `roles/home/gui.nix` imports every GUI-desktop module; stacks onto `cli.nix` → `base.nix` |
| `nix/hosts/` | *which machine this is* — instantiation | `hosts/darwin/fw-skyler/` — username, persona, system triple, host-specific overrides |
| `nix/users/` | *what a persona means* — identity, only when 2+ hosts share it | `users/personal/` — portable base + `desktop.nix` GUI add-on, shared by two machines |

A persona directory (`users/<name>/`) only earns its keep once a second host
needs it. A persona with exactly one host dissolves directly into that
host's directory instead (see `hosts/darwin/fw-skyler/` — work never got a
`users/work/`, because it never had a second machine to justify one).

> **Open question, not yet resolved:** whether `nix/users/` (identity as a
> persona directory) survives at all, or whether identity folds entirely into
> the roles layer instead. Flagged 2026-08-05, not investigated yet — see
> the redesign doc's open questions. Treat the `nix/users/` row above as
> current-state, not settled long-term.

Roles stack (`gui` → `cli` → `base`); a host should import one or two roles,
never a long list of individual modules. If a host file's import list is
growing item by item, that's the signal a role is missing, not a host quirk
to carry indefinitely.

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
