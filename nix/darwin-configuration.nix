{ config, ... }:
{

  imports = [
    ./module/homebrew.nix
  ];

  ids.gids.nixbld = 350;
  system.primaryUser = "skyler.lemay";

  # System-level user configurations
  users.users."skyler.lemay" = {
    name = "skyler.lemay";
    home = "/Users/skyler.lemay";
  };

  # Enable experimental features
  nix.settings.experimental-features = "nix-command flakes";

  # Set Git commit hash for darwin-rebuild
  system.configurationRevision = config.rev or config.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
