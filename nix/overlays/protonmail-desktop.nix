# protonmail-desktop's .desktop file lacks a StartupWMClass, so window
# managers can't match its running window back to the launcher.
_final: prev: {
  protonmail-desktop = prev.protonmail-desktop.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        echo "StartupWMClass=proton-mail" >> $out/share/applications/proton-mail.desktop
      '';
  });
}
