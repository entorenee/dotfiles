# Private Assets

Some font files live in a private repo rather than in this one. They are the
only private asset, and `nix/modules/home/fonts/default.nix` is their only
consumer.

## How it works

The fonts module fetches the repo itself, with `builtins.fetchGit` pinned to an
explicit `rev`. It is deliberately **not** a flake input.

Stock Nix fetches every locked flake input eagerly, before it knows which
outputs use them. As an input, a `git+ssh://` private repo therefore forced
every host to authenticate to GitHub just to *evaluate* — including the
headless Pi hosts (`hub`, `uptime`, `airgap`), which take `roles/home/cli.nix`
or `minimal.nix`, never import the fonts module, and have no Yubikey plugged in
to authenticate with. That is what made `make hub-switch` fail without a
`--override-input private-assets` flag. Determinate Nix's lazy trees masks the
problem on the desktop; the Pis run stock Nix and do not.

Moved into the module, the fetch is a thunk that only hosts importing
`roles/home/gui.nix` ever force.

## Does a GUI host authenticate on every rebuild?

No. A pinned `rev` is a locked input to Nix's git fetcher, so it resolves out of
`~/.cache/nix/gitv3` without touching the network:

```bash
nix eval --offline --raw --expr 'builtins.fetchGit {
  url = "ssh://git@github.com/entorenee/dotfiles-private-assets.git";
  ref = "refs/heads/main";
  rev = "e6c7e33c2608e6bda2891ca45a319694657292a3";
}'
```

Authentication is needed only on a cold cache — the first evaluation on a new
machine, or after `~/.cache/nix/gitv3` is cleared. `nix-collect-garbage` does
*not* trigger it, since that cache lives outside the store. This is the same
fetcher and cache the flake input used, so nothing about how often a GUI host
authenticates has changed.

## Repository structure

```
fonts/
├── Font1.ttf
├── Font2.otf
└── ...
```

## Bumping the pin

`nix flake update` no longer covers this. Push to the private repo, then update
`rev` in `nix/modules/home/fonts/default.nix` by hand and rebuild.

That manual step is the price of the current shape, and it is the right trade
only while the assets repo stays near-static (one commit, unchanged since July
2025). If it starts changing often enough that hand-bumping is the bigger
annoyance, move it back to a flake input — and accept that the Pi hosts then
need `--override-input private-assets 'path:/dev/null'` again. Whichever gets
bumped less should be the one done by hand.
