{...}: {
  programs.alacritty = {
    enable = true;
    theme = "tokyo_night";

    settings = {
      font = {
        normal = {
          family = "Dank Mono";
          style = "monospace";
        };
      };
    };
  };
}
