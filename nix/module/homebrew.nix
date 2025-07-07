{ ... }:
{
  imports = [
    ./karabiner
  ];

  homebrew = {
    enable = true;
    global.autoUpdate = false;

    brews = [
      "node"
      "nvm"
      "pinentry"
      "pinentry-mac"
      "Z"
    ];

    casks = [
      "docker"
      "elgato-control-center"
      "iterm2"
      "karabiner-elements"
      "obsidian"
      "rectangle"
      "vlc"
      "yubico-authenticator"
      "zoom"
    ];
  };
}
