{ ... }: {
  programs.zsh.shellAliases = {
    dc = "docker compose";
    dcu = "docker compose up -d";
    dcd = "docker compose down";
    dcl = "docker compose logs -f";
    dce = "docker compose ps --filter status=exited";
  };
}
