{config, ...}: {
  # Suppress system-installed autostart entries that degrade the user systemd
  # session on this machine (System76 HiDPI daemon, NVIDIA settings).
  # User-level Hidden=true overrides prevent the XDG autostart generator from
  # producing units at all; masking the generated units doesn't work because
  # their filenames use \x2d escaping that doesn't match plain-dash mask files.
  xdg.configFile = {
    "autostart/hidpi-daemon.desktop".text = "[Desktop Entry]\nHidden=true\n";
    "autostart/hidpi-frontend.desktop".text = "[Desktop Entry]\nHidden=true\n";
    "autostart/nvidia-settings-autostart.desktop".text = "[Desktop Entry]\nHidden=true\n";
    # 10-home-manager.conf (from targets.genericLinux) appends
    # ${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}, accumulating duplicates when the
    # systemd user manager inherits a non-empty value from PAM. The `50-` prefix
    # is load-bearing: this must be processed after it to reset the baseline.
    "environment.d/50-xdg-dedup.conf".text = ''
      XDG_DATA_DIRS=/nix/var/nix/profiles/default/share:${config.home.homeDirectory}/.nix-profile/share:/usr/share/ubuntu:/usr/local/share:/usr/share:/var/lib/snapd/desktop
    '';
  };
}
