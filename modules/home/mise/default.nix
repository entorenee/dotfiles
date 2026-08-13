{...}: {
  programs.mise = {
    enable = true;
    globalConfig.settings.idiomatic_version_file_enable_tools = ["node"];
  };
}
