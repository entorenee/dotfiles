{ username, ... }:
{
  homebrew.brews = [
    "nvm"
  ];
  # TODO: previously my setup script made sure that LTS was installed
  # Determine if this will get ported over to the Nix setup
  # nvm install --lts
  # nvm alias default 'lts/*'

  home-manager.users."${username}" = { ... }: {
    xdg.configFile."nvm".source = ./config;
  };
}
