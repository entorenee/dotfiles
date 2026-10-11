{pkgs, ...}: {
  # CD ripper. Rips land in ~/Music/import for `beet import` to tag and file.
  home.packages = [pkgs.abcde];

  # abcde sources this file as shell, so $HOME expands at rip time.
  home.file.".abcde.conf".text = ''
    OUTPUTTYPE=flac
    OUTPUTDIR="$HOME/Music/import"
  '';
}
