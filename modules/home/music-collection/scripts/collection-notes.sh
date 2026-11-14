# Add a vault note for every beets album that lacks one. Dry-run by default,
# listing albums whose matched edition isn't the owned medium; pass --write.
# Field order must match FIELDS in beets-to-vault.py.
beet ls -a -f $'$albumartist\t$album\t$original_year\t$media\t$label\t$catalognum\t$mb_albumid\t$mb_releasegroupid\t$owned_media' |
  python3 -I "$GENERATOR" "$RELEASES_DIR" "$@"
