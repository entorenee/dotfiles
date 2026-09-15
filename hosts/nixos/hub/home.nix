{config, ...}: let
  personalYubikeyIdentity = "${config.home.homeDirectory}/.ssh/id_rsa_yubikey_personal.pub";
in {
  # Replaces the module's `mkDefault` list rather than appending to it, so the
  # personal Yubikey has to be restated — it authenticates the dotfiles checkout
  # on every machine.
  #
  # The order is the opposite of the obvious one and is load-bearing. A
  # read-only deploy key *authenticates successfully* and only then fails at the
  # git layer, and ssh does not fall through to another identity once auth has
  # succeeded — offering it first would break Yubikey-signed pushes from hub.
  # Second, it is reached only when the agent cannot produce the Yubikey key,
  # which ssh skips cleanly: Yubikey plugged in → full account access; Yubikey
  # absent → unattended read-only pulls.
  programs.ssh.settings."github.com".IdentityFile = [
    personalYubikeyIdentity
    "${config.home.homeDirectory}/.ssh/id_ed25519_hub"
  ];
}
