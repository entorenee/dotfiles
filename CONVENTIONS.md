# Nix Configuration Conventions

The durable architectural reference for how this repo is put together — the rules
that should still hold long after any particular migration is done. `CLAUDE.md`
is the other half: it tells Claude Code how to behave here (commands,
permissions, communication). Some of the architecture is described in both
places; when a structural question comes up, answer it here rather than in two.

**Don't cite an uncommitted file as an authority.** This one used to point at a
gitignored plan doc for the reasoning behind a past decision, so the reference
was broken in every checkout but the one that wrote it — and then that file left
the repo entirely. Reasoning worth keeping belongs here, inside the rule it
explains. Naming a machine-local artifact is fine when it is an optional cache,
as long as you say it may be absent and what to do then;
`modules/home/claude/config/skills/skill-reviewer/SKILL.md` gets this right for
its ledger.

Paths below are repo-relative — `flake.nix` and everything under it sit at the
root, next to this file.

---

## The three-way rule

Every difference between hosts is one of three things, and working out which
one settles the mechanism for you:

| Kind               | Question                                              | Mechanism                                                                                                                         |
| ------------------ | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **Platform truth** | Is this a fact about the OS/architecture itself?      | `pkgs.stdenv.isDarwin` / `isLinux`, inline                                                                                        |
| **Capability**     | Does a _class_ of machine have or lack some property? | a `my.*` option in `modules/options.nix`                                                                                          |
| **Identity**       | Does only _this job/host_ want this at all?           | an import — an identity role file (`roles/home/personal*.nix`, `roles/darwin/personal.nix`), `hosts/<host>/`, or a tier role file |

**Platform truth can stay inline**, shared module or not. `gnupg` reaching for
`pinentry-mac` on Darwin, `rtk`'s config path, `firefox` set to `null` on a Mac
because Homebrew owns it there — all correct as written. These are facts, not
decisions; leave them alone.

**Capability and identity are the two that get mixed up, and mixing them up is
the recurring bug here.** `pkgs.stdenv.isLinux` does not mean "has a GUI" — it
only reads that way while every Linux host happens to be a desktop. Add a
headless Pi and anything gated on `isLinux` leaks onto it. The answer is never
more `isLinux` special-casing:

- "any machine with a GUI wants this" → gate on `config.my.gui`.
- "only this host or this job wants this" → drop the conditional entirely and
  make it an import. A module imported _only_ from `roles/home/gui.nix`
  (`aerospace`, `karabiner`, `alacritty`, `linux-gui-pkgs.nix`) can then
  self-gate on pure platform truth inside itself, because the capability gate
  already happened at the import site. That is the two mechanisms composing, not
  a contradiction of the rule above.

A host-specific block living in a shared module because there is nowhere else
for it yet means the identity axis is missing a home. Give it a `hosts/<name>/`
file and import it from there, unconditionally.

## The three-layer taxonomy

| Layer      | Says                                                                    | Example                                                                                                                                                                                                                                         |
| ---------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `modules/` | _how_ a tool is configured — mechanism                                  | `modules/home/nvim/` sets up Neovim; says nothing about who wants it                                                                                                                                                                            |
| `roles/`   | _which class of machine, or which job,_ wants a set of modules — policy | `roles/home/gui.nix` imports every GUI-desktop module and stacks onto `cli.nix` → `base.nix`; `roles/home/personal.nix` and `roles/darwin/personal.nix` carry the personal job; `roles/nixos/base.nix` carries what every Pi is                 |
| `hosts/`   | _which machine this is_ — instantiation                                 | `hosts/darwin/fw-skyler/` — `{username, system, homeImports, darwinImports ? [], overlays ? []}`, plus that machine's own host-specific files; `hosts/nixos/hub/` — the same shape with `nixosImports`, plus that machine's `configuration.nix` |

> **`users/` is gone, dissolved into `roles/`.** Work versus personal was never
> two people, it is two jobs one machine can do — which is a question of what
> gets installed. `hub` already ran home-manager with no persona at all, and
> `modules/home/git/` has always sorted work from personal by
> `includeIf "gitdir:"` — by checkout, not by machine. Those files are now
> `roles/home/personal{,-desktop,-claude}.nix`, `roles/home/personal-gh-dash.yml`
> and `roles/darwin/personal.nix`. Work never had a persona directory and still
> doesn't: `fw-skyler` is the only work machine, so its files live under
> `hosts/darwin/fw-skyler/`.
>
> What would bring a persona layer back is a second _person_ — a shared machine,
> someone else's account. A host file merely getting long is not that.

**A host composes itself; nothing is spliced onto it.** `homeImports` is one
ordered list naming a tier role plus whatever identity or host-specific modules
that machine wants, and `darwinImports` is its nix-darwin counterpart. There is
no `user` path field, no filename contract for the flake to build paths from, and
no separate `extraHomeImports` — `lib/{darwin,home}.nix` pass both lists through
verbatim. Since the tier role is named by the host instead of hardcoded in
`flake.nix`, a new host that wants `cli` instead of `gui` just says so.

**The Pis are not an exception to any of that.** One states
`{system, nixosImports, username ? null, homeImports ? []}` in
`hosts/nixos/<name>/default.nix`, `flake.nix` instantiates it with
`mkNixosHost ./hosts/nixos/<name>`, and `nixosImports` is simply the third import
list — the NixOS counterpart of `darwinImports`. `lib/nixos.nix` hardcodes no
role of its own: `hub` names `roles/home/cli.nix` itself, exactly as the Macs
name `roles/home/gui.nix`. Omitting `username` means no home-manager, and with
it no overlays and no `allowUnfree` — those sit inside the `username != null`
branch deliberately, so a home-manager-less host evaluates to what it always has.

**Identity role files sit flat in `roles/home/`, beside the tier roles**, with
the `personal-` filename prefix doing the grouping. A subdirectory of their own
would reintroduce the very layer the dissolution removed. They don't stack the
way the tiers do — a host names the ones it wants.

The tiers do stack (`gui` → `cli` → `base` → `minimal`), and a host should name
one tier plus the identity roles for the job it does, never a long list of
individual modules. An import list growing item by item is the signal that a
role is missing, not a host quirk to carry forever.

| Role      | Adds                                              | For                                                                          |
| --------- | ------------------------------------------------- | ---------------------------------------------------------------------------- |
| `minimal` | shell, prompt, bare editor, small local CLI tools | the floor — nothing assuming a network, a remote, or a `~/dotfiles` checkout |
| `base`    | git, ssh, gnupg, `bins`, the LazyVim config       | a networked machine I log into                                               |
| `cli`     | dev tooling, language runtimes, Claude, tmux      | a machine that is actually developed on                                      |
| `gui`     | terminal emulators, fonts, desktop apps           | a machine with a display                                                     |

`roles/` splits by module system the way `modules/` does — `roles/home/`,
`roles/darwin/`, `roles/nixos/` — because a home-manager role can't set
`homebrew.casks` and a NixOS role can't set `home.packages`. The stacking tiers
are a `roles/home/` idea specifically; `roles/nixos/base.nix` is one flat policy
file every Pi imports, and it earns tiers of its own only once a second class of
NixOS machine shows up.

**Compose downward, don't subtract.** A host needing less than a role provides
takes the tier below and adds what it wants; it does not take the higher tier and
remove things. `disabledModules` is built for swapping in a fork, not for opting
out, and goes silently wrong the moment another role adds the module back by a
different path — and per-module `enable` flags would mean an options block on
every module to serve one host. If no tier is low enough, write a new tier.

A role plus one or two deliberate module imports is fine for a host that is
permanently a class of one — the airgap Pi wanting `gnupg` and nothing else
networked. The warning above is about hosts that are instances of a _class_;
those want a role.

## `my.*` capability options

Declared in `modules/options.nix`, and kept deliberately few. An option earns its
place once a module a host _already imports_ has to behave differently depending
on it — not speculatively, in case it's useful later. Wait for the second real
consumer.

Some are explicitly **transitional**: `my.dotfiles.mutable` exists only because
out-of-store symlinks aren't fully retired. When the reason for a transitional
option goes away, delete the option rather than leaving dead configuration
surface behind. Read an option's doc comment before building on it — it may say
as much.

## Secrets

`.age` ciphertext is committed to `secrets/`, in the open, and
`secrets/secrets.nix` says which machines can open which file. Publishing
ciphertext was a deliberate call, not something to reconsider per secret.

**Recipients are machines, never people.** `age` speaks neither GPG nor
ssh-agent, so the Yubikey this repo otherwise leans on simply cannot be one —
that constraint is what shapes the rest. The Pis decrypt with the sshd host key
they already have; each desktop gets an age identity at
`~/.config/age/keys.txt`, placed by hand once, and that single bootstrap opens
everything sent to it afterwards.

An offline **break-glass** identity is a recipient on every secret. It isn't a spare copy: rekeying
reads every file at once, so only an identity already on all of them can add a
recipient to any of them. Leave it off a new secret and nothing can ever be added
to that secret again.

Adding one: name it in `secrets/secrets.nix`
(`"<name>.age".publicKeys = [breakGlass <machine>];`), run
`cd secrets && agenix -e <name>.age`, then declare an `age.secrets.<name>` entry
— system level on a Pi, home-manager level on a desktop, since the Macs
deliberately skip agenix's nix-darwin module. **The `.age` has to be
git-tracked**: the flake can't see an untracked file, and the failure surfaces as
a missing path rather than as anything to do with decryption.

A desktop's _first_ secret also needs `age.identityPaths`. It is a per-host
option, set once and not per secret: the home-manager module defaults to
`~/.ssh/id_ed25519` and `~/.ssh/id_rsa`, and neither exists on these machines —
the identity is the hand-placed `~/.config/age/keys.txt`.

**`path` is a symlink, not the decrypted file.** Plaintext is written to a
runtime directory — `$XDG_RUNTIME_DIR/agenix` on Linux, `$(getconf
DARWIN_USER_TEMP_DIR)/agenix` on macOS, a ramfs under `/run/agenix` on the Pis —
and `path` is linked at it. ssh follows the link and checks the _target's_ mode,
which is what the entry's `mode` sets. None of it survives a reboot, so a secret
that decrypts once is not thereby proven to decrypt on a cold boot.

**On a new machine, run `make friction-remote` once after the first rebuild.**
agenix places the friction log's deploy key, but nothing declarative points the
checkout at it: `services.git-sync`'s `uri` applies only when cloning a directory
that does not exist, and on macOS not at all. The target clones the repo through
the `claude-friction.github.com` alias, or re-points an older checkout at it.

Skip it and the sync uses the plain `github.com` remote, which matches the
Yubikey block in `modules/home/ssh` — a key no background daemon can touch. It
then fails every five minutes, reporting a network problem. If a push fails with
`Permission denied (publickey)`, check the remote before anything else. A second
cause looks similar: a leftover `id_ed25519_friction.pub` from before agenix
makes ssh refuse the key outright (`contents do not match public`), and the fix
is to delete the `.pub` — ssh derives it from the private key.

## Overlays

One overlay function per file in `overlays/`, applied where each config's `pkgs`
is actually built — never inside a home-manager module once `useGlobalPkgs` is in
play, since there's no separate `pkgs` left there to configure. Two shapes:

- **Host-scoped**, the common case: a host's own file sets `overlays = [...]` and
  only that host gets it — `pnpm-pin.nix` (one work monorepo),
  `protonmail-desktop.nix` (one Linux desktop's `.desktop` patch, applied to
  the unstable package via `final.unstable`).
- **Universal**: threaded as `baseOverlays` onto every host in `flake.nix`, for
  something every current _and planned_ host needs.
  `unstable.nix` qualifies because `programs.claude-code` reaches every host
  through `roles/home/cli.nix`; it also exposes `pkgs.unstable`, so a package
  wanted from unstable is named as `unstable.<pkg>` (or built on in a
  host-scoped overlay) rather than earning an overlay of its own. The other is
  `agenix.overlays.default` — an overlay a flake input supplies rather than an
  `overlays/` file — universal because `pkgs.agenix` is how any secret gets
  edited.

Don't reach for universal first. A host-scoped overlay that turns out to be
needed everywhere gets promoted deliberately; it doesn't start broad to be safe.

## Config drift is expected — audit for it, don't just avoid it going forward

A module written before a convention existed does not retroactively follow it.
Two worked examples, both since resolved — they are kept because the shape of
the drift is the lesson, not because either file still reads that way.
`modules/home/pkgs.nix`'s `linuxPkgs` list predated `my.gui` and was never
revisited once that option existed; it has since been split into
`modules/home/{minimal,cli,linux-gui}-pkgs.nix`, where the importing role is the
GUI gate and only `pkgs.stdenv.isLinux` is checked in the module. And
`roles/home/base.nix`'s autostart-suppression block predated `hosts/home/`
having a real per-host file and carried a TODO saying so for several steps; it
now lives at `hosts/home/hester-prynne/autostart-suppression.nix`. Neither was
sloppy when written — the convention each came to violate didn't exist yet, and
nothing forces a stale module to be rechecked unless something puts it back in
view.

So when a session's work newly exercises an old, previously-static module —
especially by adding a new _kind_ of host rather than another instance of an
existing kind — treat that as the prompt to check it against current
conventions, not just against whether it evaluates. "It's always worked" is a
different claim from "it matches the current rule."
