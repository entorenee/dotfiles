{ ... }: {
  programs.zsh.shellAliases = {
    ni = "npm install";
    nis = "npm install --save";
    nid = "npm install --save-dev";
    ns = "npm start";
    nr = "npm run";
    nt = "npm test";
  };
}
