{
  username,
  ...
}:
{
  ids.gids.nixbld = 350;

  # System-level user configurations
  users.users.${username}.home = "/Users/${username}";

  # Enable experimental features
  nix.settings.experimental-features = "nix-command flakes";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
