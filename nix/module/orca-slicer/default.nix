{
  config,
  lib,
  pkgs,
  profile,
  ...
}: let
  orcaConfigPath = "${config.home.homeDirectory}/dotfiles/nix/module/orca-slicer/config";
  isPersonalProfile = profile == "personal";
  # nixpkgs bumped GLEW 2.2.0 → 2.3.1 and added -DGLEW_EGL=ON. The EGL-aware
  # GLEW dispatches through EGL on Wayland and calls glGetString(GL_VERSION)
  # before wxGLCanvas has made its context current, causing every glewInit()
  # call to fail with "Missing GL version" and leaving the viewport blank.
  # Rebuild GLEW without EGL support to restore the GLX-only init path.
  #
  # LD_PRELOAD wins over LD_LIBRARY_PATH, so our custom GLEW is loaded even
  # though the nixpkgs C wrapper later prepends the EGL-aware GLEW 2.3.1.
  #
  # DRI_PRIME=1 is also set by the Pop!_OS GPU-switching session but this
  # machine has only one GPU; Mesa rejects the value as a warning.
  # nixpkgs glew cmakeFlags is a string, not a list, so filter won't work;
  # explicitly set the flags we want instead of trying to remove the EGL one.
  glew-no-egl = pkgs.glew.overrideAttrs (_: {
    cmakeFlags = ["-DBUILD_SHARED_LIBS=ON"];
  });
  orca-slicer-wrapped = pkgs.symlinkJoin {
    name = "orca-slicer";
    paths = [pkgs.orca-slicer];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/orca-slicer \
        --unset DRI_PRIME \
        --set LD_PRELOAD "${glew-no-egl.out}/lib/libGLEW.so"
    '';
  };
in {
  home.packages = lib.mkIf pkgs.stdenv.isLinux [orca-slicer-wrapped];

  xdg.configFile."OrcaSlicer/user" = lib.mkIf isPersonalProfile {
    source = config.lib.file.mkOutOfStoreSymlink orcaConfigPath;
  };
}
