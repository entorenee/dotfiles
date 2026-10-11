{pkgs, ...}: {
  # CD ripper. Rips land in ~/Music/import for `beet import` to tag and file.
  home.packages = [pkgs.abcde];

  # abcde sources this file as shell, so $HOME expands at rip time.
  # WAVOUTPUTDIR is defaulted from OUTPUTDIR *before* this file is read, so it
  # falls back to $PWD unless set here too.
  home.file.".abcde.conf".text = ''
    EJECTCD=y
    OUTPUTTYPE=flac
    OUTPUTDIR="$HOME/Music/import"
    WAVOUTPUTDIR="$HOME/Music/import"
  '';
}
