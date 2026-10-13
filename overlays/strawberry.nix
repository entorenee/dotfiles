# Backports nixpkgs PR #560021 (strawberry 1.2.21 -> 1.2.31) onto unstable's
# derivation, for the scrobbling fixes. Drop once that PR reaches
# nixos-unstable and switch the package list back to `unstable.strawberry`.
final: prev: {
  strawberry = prev.unstable.strawberry.overrideAttrs (finalAttrs: old: {
    version = "1.2.31";

    src = final.fetchFromGitHub {
      owner = "strawberrymusicplayer";
      repo = "strawberry";
      rev = finalAttrs.version;
      hash = "sha256-U9qRaadhhHmzWBPS4QhofKAyVkZ+o7+emfNuRZRKWA0=";
    };

    # apicredentials.h ships only in the release tarball, not in git.
    releaseTarball = final.fetchurl {
      url = "https://github.com/strawberrymusicplayer/strawberry/releases/download/${finalAttrs.version}/strawberry-${finalAttrs.version}.tar.xz";
      hash = "sha256-z/wM1FPzEmqTC55n9UflTZ/eDIdU/erYGF0rL1xowDc=";
    };

    # The gst-app test-link patch was merged upstream.
    patches = [];

    postPatch =
      ''
        tar -xOf "${finalAttrs.releaseTarball}" "strawberry-${finalAttrs.version}/src/apicredentials.h" > src/apicredentials.h
      ''
      + old.postPatch;

    buildInputs = old.buildInputs ++ [final.libsecret final.libuchardet];
  });
}
