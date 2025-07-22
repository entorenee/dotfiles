{
  username,
  ...
}:
{
  ids.gids.nixbld = 350;

  # System-level user configurations
  users.users.${username}.home = "/Users/${username}";

  nix = {
    enable = false;

    settings = {
      experimental-features = "nix-command flakes";
      warn-dirty = false;
    };
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
