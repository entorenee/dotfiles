{worktrunk, ...}: {
  imports = [worktrunk.homeModules.default];

  programs.worktrunk = {
    enable = true;
    enableZshIntegration = true;
  };
}
