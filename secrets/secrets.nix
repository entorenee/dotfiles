# The `agenix` CLI reads this; the flake never evaluates it. The CLI looks for
# ./secrets.nix in the working directory, so run `agenix -e` from inside here.
#
# Do not add a Yubikey here: age speaks neither GPG nor ssh-agent, so every
# recipient has to be a machine identity. See CONVENTIONS.md, "Secrets".
#
# breakGlass belongs on every entry below: `agenix -r` decrypts *every* file
# listed here and aborts on the first it cannot read, so an entry that omits it
# can never gain a recipient afterwards.
let
  # Offline, generated on airgap. Private half: KeePassXC + offline media.
  breakGlass = "age13ljclxmzkrvnyynzuzwf8dy4tggneedpet4xtlzz07p3se340d6s2r8l6q";

  # hub's sshd host key, pasted verbatim. The trailing `root@nixos` is sshd's
  # default label; age matches on key material alone, so don't tidy it to `hub`.
  hubHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGd15a4vpLYCxY7gNHflAiuYmZVyxQvM8iM3L+jGw4Md root@nixos";

  # The desktops' hand-placed identities at ~/.config/age/keys.txt. Each machine
  # is on its own secret's recipient list, so unlike hub's keys these stay
  # re-editable from the machine that owns them.
  hesterUser = "age147etejh9d4ymfs26pfasz2j2f454fn2u8whmzuygwg47938mxfnqhpg8ke";
  fwUser = "age12qnppa5s2gdut38lakharaq3vufpr57j3y0ud567c58wwnva952qtld9m4";
  lyraUser = "age1s54j9zy0ps97vhzxtu5m5rl9w5gxrwjlfeayx7wk2qs0hg3fa3wsawl994";
in {
  "friction-deploy-hub.age".publicKeys = [breakGlass hubHost];
  "dotfiles-deploy-hub.age".publicKeys = [breakGlass hubHost];

  # One write key per machine, so revoking a machine at GitHub revokes exactly
  # that machine.
  "friction-deploy-hester-prynne.age".publicKeys = [breakGlass hesterUser];
  "friction-deploy-fw-skyler.age".publicKeys = [breakGlass fwUser];
  "friction-deploy-lyra-silvertongue.age".publicKeys = [breakGlass lyraUser];
}
