{
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ../../../roles/nixos/base.nix
  ];

  networking.hostName = "uptime";
  # The Zero 2W has no on-board ethernet; this is a USB OTG adapter.
  networking.useDHCP = true;

  # The account set is fully declared, so an imperative `passwd` cannot persist
  # and re-open what the openssh settings below close.
  users.mutableUsers = false;

  users.users.uptime = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keyFiles = [
      ../../../modules/home/ssh/public-ssh-keys/id_rsa_yubikey_personal.pub
    ];
  };

  # uptime is passwordless, so password-authenticated sudo cannot work. Needed
  # for the `--sudo` in `make uptime-switch`; login is Yubikey-backed SSH only.
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Note that uptime-kuma does not run as the uptime user: the upstream module
  # hardcodes DynamicUser, and its state lives in /var/lib/uptime-kuma. The
  # uptime user exists purely for SSH administration.
  #
  # HOST and PORT match the module's own defaults, but are set explicitly
  # because /etc/cloudflared/config.yml is written by hand off-repo and has to
  # point its ingress rule at them.
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = "3001";
    };
  };

  # The tunnel UUID, public hostname and ingress rules are deliberately absent
  # from this repo. Drop config.yml and credentials.json into /etc/cloudflared
  # (either onto the mounted image before flashing or over SSH afterwards) and
  # the tunnel comes up on the next boot.
  #
  # Not services.cloudflared: its tunnels.<uuid> submodule takes the UUID as an
  # attribute name and renders ingress into a store-built config.yml, making
  # both eval-time inputs — i.e. published in this repo.
  #
  # ConditionPathExists keeps the unit quiet on a card that has not been seeded
  # yet, rather than crash-looping until it hits the restart limit.
  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare tunnel fronting uptime-kuma";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    unitConfig.ConditionPathExists = "/etc/cloudflared/config.yml";
    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared --no-autoupdate --config /etc/cloudflared/config.yml tunnel run";
      User = "cloudflared";
      Group = "cloudflared";
      Restart = "on-failure";
      RestartSec = 10;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
    };
  };

  users.groups.cloudflared = {};
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };

  # The `z` rules re-apply ownership and mode to whatever was dropped in, so
  # seeding the files on the build machine (where the cloudflared uid does not
  # exist yet) still ends up readable by the service after first boot.
  systemd.tmpfiles.rules = [
    "d /etc/cloudflared 0750 root cloudflared -"
    "z /etc/cloudflared/config.yml 0640 root cloudflared -"
    "z /etc/cloudflared/credentials.json 0640 root cloudflared -"
  ];

  # For reading and editing config on the box, not for rebuilding — evaluating
  # a NixOS closure needs more RAM than the Zero has, so deploys come from the
  # Pi 4 via `make uptime-switch`.
  systemd.services.clone-dotfiles = {
    description = "Clone dotfiles for on-device reference";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    unitConfig.ConditionPathExists = "!/home/uptime/dotfiles/.git";
    environment.GIT_SSL_CAINFO = "/etc/ssl/certs/ca-certificates.crt";
    serviceConfig = {
      Type = "oneshot";
      User = "uptime";
      Group = "users";
      ExecStart = "${pkgs.git}/bin/git clone https://github.com/entorenee/dotfiles.git /home/uptime/dotfiles";
    };
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # 512MB of RAM, and a journal that would otherwise chew through the SD card.
  zramSwap.enable = true;
  services.journald.extraConfig = "SystemMaxUse=64M";

  environment.systemPackages = with pkgs; [
    cloudflared
    git
  ];

  # boot.loader.*, fileSystems."/", and fileSystems."/boot/firmware" are
  # already set by sd-image-aarch64.nix.
}
