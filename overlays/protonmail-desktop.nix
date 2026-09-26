# protonmail-desktop from nixpkgs-unstable (needs overlays/unstable.nix, a base
# overlay), whose .desktop file lacks a StartupWMClass, so window managers can't
# match its running window back to the launcher.
final: _prev: {
  protonmail-desktop = final.unstable.protonmail-desktop.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        echo "StartupWMClass=proton-mail" >> $out/share/applications/proton-mail.desktop
      '';
  });
}
