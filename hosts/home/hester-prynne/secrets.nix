{config, ...}: {
  age.identityPaths = ["${config.home.homeDirectory}/.config/age/keys.txt"];

  age.secrets.friction-deploy = {
    file = ../../../secrets/friction-deploy-hester-prynne.age;
    path = "${config.home.homeDirectory}/.ssh/id_ed25519_friction";
    mode = "0400";
  };

  # agenix.service and git-sync-claude-friction.service are both wanted by
  # default.target with nothing ordering them. git-sync retries every 300s so it
  # self-heals either way; this removes the failed first run after a rebuild.
  # Unit name comes from `systemctl --user list-units 'git-sync*'`.
  systemd.user.services.git-sync-claude-friction.Unit.After = ["agenix.service"];
}
