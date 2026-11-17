{lib, ...}: {
  # Declared apart from default.nix only so that module can stay a plain config
  # body; a module that declares `options` must move everything else under
  # `config`.
  options.my.claude.excluded = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["investigate" "dependency-scoper"];
    description = ''
      Skill directory names and agent basenames under ./config to leave
      undeployed on this host, along with their derived Skill(<name>) permission.
      For skills a repo ships as project skills: with both installed it is
      unclear which one runs, so the host keeps only the repo's copy.
    '';
  };
}
