# Navi Configuration

Clean, flake-based navi configuration using home-manager's native module and XDG directories.

## Recommended Approach: Cheatsheets Flake

This approach uses a separate flake to bundle cheatsheet repositories with navi's native directory structure.

### Step 1: Create or Use a Cheatsheets Flake

Create a separate flake that bundles your desired cheatsheet repositories:

```nix
# navi-cheatsheets-flake.nix (or as a separate repository/gist)
{
  description = "Navi cheatsheets bundle";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          cheatsheetRepos = [
            {
              owner = "denisidoro";
              repo = "cheats";
              rev = "master";
              sha256 = "sha256-..."; # Get with nix-prefetch-url --unpack
            }
            {
              owner = "cheat";
              repo = "cheatsheets";
              rev = "master";
              sha256 = "sha256-...";
            }
          ];

          naviCheatsheets = pkgs.runCommand "navi-cheatsheets" {} ''
            mkdir -p $out
            ${pkgs.lib.concatMapStrings (repoSpec:
              let
                src = pkgs.fetchFromGitHub {
                  inherit (repoSpec) owner repo rev sha256;
                };
                dirName = "${repoSpec.owner}__${repoSpec.repo}";
              in ''
                cp -r "${src}" "$out/${dirName}"
                chmod -R u+w "$out/${dirName}"
              ''
            ) cheatsheetRepos}
          '';
        in {
          default = naviCheatsheets;
        });
    };
}
```

### Step 2: Add as Flake Input

Add the cheatsheets flake as an input to your main flake:

```nix
# flake.nix
{
  inputs = {
    # ... existing inputs
    navi-cheatsheets = {
      url = "path:./module/navi";
      # or url = "github:yourusername/navi-cheatsheets";
    };
  };

  outputs = { self, nixpkgs, home-manager, navi-cheatsheets, ... }: {
    # ... existing outputs
  };
}
```

### Step 3: Pass Through Darwin Config

Update your system configuration to pass the cheatsheets:

```nix
# system/darwin.nix - add navi-cheatsheets to inputs
{
  home-manager,
  darwin,
  nixpkgs,
  username,
  profile,
  navi-cheatsheets,
  ...
}:
system:
# ... let block
darwin.lib.darwinSystem {
  inherit system;
  modules = [
    home-manager.darwinModules.home-manager
    {
      home-manager.users."${username}" = {
        imports = [ home-manager-config ];
        _module.args = {
          inherit lib username profile;
          navi-cheatsheets = navi-cheatsheets.packages.${system}.default;
        };
      };
      # ... rest
    }
  ];
}
```

### Step 4: Update Flake Outputs

```nix
# flake.nix outputs
let
  mkDarwinConfig = username: profile: system: import ./system/darwin.nix {
    inherit
      home-manager
      darwin
      nixpkgs
      username
      profile
      navi-cheatsheets
      ;
  } system;
in
{
  # ... darwinConfigurations
};
```

## How It Works

1. **Native Directory Structure**: Maintains navi's expected `owner__repo` directory structure
2. **XDG Compliance**: Symlinks cheatsheets to `~/.local/share/navi/cheats/` (navi's default)
3. **Home Manager Integration**: Uses the official home-manager navi module
4. **Clean Separation**: Cheatsheet management is separated from your dotfiles configuration

## Benefits

- ✅ **Native navi structure**: Works exactly like `navi repo add`
- ✅ **Clean module**: Uses home-manager's official navi module
- ✅ **XDG compliant**: Follows XDG base directory specification
- ✅ **Single flake input**: Manage all cheatsheets through one input
- ✅ **Easy updates**: `nix flake update` updates all cheatsheets
- ✅ **Reproducible**: Lock file ensures consistent builds

## Usage After Setup

Once configured, navi will automatically find your cheatsheets:

```bash
# Search all cheatsheets
navi

# List available cheatsheets
navi info cheats-path
ls $(navi info cheats-path)

# Update cheatsheets (rebuild your system)
darwin-rebuild switch
```

## Getting SHA256 Hashes

To get SHA256 hashes for repositories:

```bash
nix-prefetch-url --unpack https://github.com/owner/repo/archive/refs/heads/main.tar.gz
```

Or use a dummy hash first - Nix will show the correct one when it fails.

## Popular Cheatsheet Repositories

- [denisidoro/cheats](https://github.com/denisidoro/cheats) - Official navi cheatsheets
- [cheat/cheatsheets](https://github.com/cheat/cheatsheets) - Community cheatsheets
- [tldr-pages/tldr](https://github.com/tldr-pages/tldr) - Simplified man pages

## Alternative: Separate Repository

For even cleaner separation, create your cheatsheets flake as a separate repository:

```bash
# Create a new repo with your cheatsheets flake
gh repo create my-navi-cheatsheets --public
```

Then reference it in your main flake:

```nix
inputs.navi-cheatsheets.url = "github:yourusername/my-navi-cheatsheets";
```

