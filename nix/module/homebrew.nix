{ ... }:
{
  imports = [
    ./ghostty
    ./iterm2 # likely to be deprecated pending trial of ghostty
    ./karabiner
    ./nvm
  ];

  homebrew = {
    enable = true;
    global.autoUpdate = false;

    brews = [
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
