{...}: {
  programs.gh = {
    enable = true;
    settings = {
      version = "1";
      git_protocol = "ssh";
      editor = "nvim";
      prompt = "enabled";
      prefer_editor_prompt = "enabled";
      spinner = "enabled";
      aliases = {
        co = "pr checkout";
        cpr = "pr create --web";
        vpr = "pr view --web";
        vr = "repo view --web";
      };
    };
  };
}
