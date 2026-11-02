# euphonica from nixpkgs-unstable (needs overlays/unstable.nix, a base overlay),
# held at 0.99.8-beta. 0.99.8-beta-1's sidebar sets AdwSidebarSection:suffix,
# which needs libadwaita 1.10, and aborts at startup on 1.9. Drop this once
# unstable ships libadwaita >= 1.10.
final: _prev: {
  euphonica = final.unstable.euphonica.overrideAttrs (finalAttrs: _old: {
    version = "0.99.8-beta";
    src = final.unstable.fetchFromGitHub {
      owner = "htkhiem";
      repo = "euphonica";
      tag = "v${finalAttrs.version}";
      hash = "sha256-AKM/gyvndgq2rnusoI/TU3C9hIplymQH/RxgBFE42Rs=";
      fetchSubmodules = true;
    };
    cargoDeps = final.unstable.rustPlatform.fetchCargoVendor {
      inherit (finalAttrs) pname version src;
      hash = "sha256-ppWKQkQu37HNvG37I9BEO+MA/pU29kZ7w3KGdzXLbVM=";
    };
  });
}
