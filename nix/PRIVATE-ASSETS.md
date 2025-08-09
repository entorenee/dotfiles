# Private Assets Support

This configuration supports optional private assets that gracefully fall back when unavailable.

## How it works

The flake uses `builtins.tryEval` and `builtins.fetchGit` to attempt fetching private assets during evaluation. If authentication fails or the repository is unavailable, it continues with `private-assets = null` and public assets only.

## Private Repository Structure

The private assets repository should have:

```
fonts/
├── Font1.ttf
├── Font2.otf
└── ...
```

## Implementation Details

- Single `flake.nix` file handles both scenarios - no duplication
- Uses `builtins.tryEval` to catch authentication failures gracefully
- The `fonts/default.nix` module checks if `private-assets` is available and contains a `fonts/` directory
- If available, fonts are copied into the Nix store and added to the font packages
- If unavailable, the system continues with only public fonts
- Requires `--impure` flag for `builtins.fetchGit` to work
- The fallback is completely transparent to the user

## Troubleshooting

If you see "error: access to URI '...' is forbidden in restricted mode", add the `--impure` flag to your nix command.

