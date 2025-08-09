# Private Assets Support

This configuration supports optional private assets that gracefully fall back when unavailable.

## How it works

The flake includes `private-assets` as an explicit input. For normal builds with SSH authentication, it fetches the private repository. For initial setup or when SSH isn't available, you can override the input to use an empty directory instead.

## Private Repository Structure

The private assets repository should have:

```
fonts/
├── Font1.ttf
├── Font2.otf
└── ...
```

## Usage

### Normal build (with SSH authentication)
```bash
# Using Makefile targets (recommended)
make pRebuild  # Personal profile
make wRebuild  # Work profile

# Or directly with nix-darwin
sudo darwin-rebuild switch --flake nix/#personal
```

### Bootstrap build (without SSH authentication)
```bash
# For initial setup when private repo is unavailable
sudo darwin-rebuild switch --override-input private-assets 'path:nix/.empty-private-assets' --flake nix/#personal
```

### Testing

```bash
# Test normal mode (requires SSH authentication)
cd nix && nix flake check --no-build

# Test fallback mode (works without authentication)
cd nix && nix flake check --override-input private-assets 'path:./.empty-private-assets' --no-build

# Test fonts config evaluation in fallback mode
cd nix && nix eval --override-input private-assets 'path:./.empty-private-assets' '.#darwinConfigurations.personal.config.home-manager.users."USERNAME".fonts.fontconfig.enable'
```

## Implementation Details

- Single `flake.nix` file with explicit `private-assets` input
- Uses `--override-input` for graceful fallback during initial setup
- The `fonts/default.nix` module checks if `private-assets` is available and contains a `fonts/` directory
- If available, fonts are copied into the Nix store and added to the font packages
- If unavailable (empty override), the system continues with only public fonts
- Pure evaluation - no `--impure` flag needed
- Proper dependency tracking and caching via flake.lock
- Reproducible builds in both modes

