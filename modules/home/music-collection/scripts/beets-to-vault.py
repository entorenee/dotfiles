"""Write one Releases/ note per beets album. Reads `beet ls -a -f` output
(tab-separated, FIELDS order) on stdin; collection-notes supplies it.
Skips notes that already exist. Dry-run unless --write.
Usage: beets-to-vault.py <Releases dir> [--write]"""

import json
import re
import sys
from pathlib import Path

FIELDS = ["albumartist", "album", "original_year", "media", "label",
          "catalognum", "mb_albumid", "mb_releasegroupid", "owned_media"]
# beets `media` patterns for an edition matching each owned_media value.
EDITION = {
    "cd": re.compile(r"(\d+x)?(Enhanced |HD|SHM-|Blu-spec )?CD", re.I),
    "vinyl": re.compile(r'(\d+x)?(\d+" )?Vinyl', re.I),
    "digital": re.compile(r"Digital Media", re.I),
}
LABEL = {"cd": "CD", "vinyl": "Vinyl", "digital": "Digital"}
BAD = re.compile(r'[\\/:*?"<>|#^\[\]]')

out_dir = Path(sys.argv[1])
write = "--write" in sys.argv


def y(v):
    # JSON strings are valid YAML double-quoted scalars.
    return json.dumps(v, ensure_ascii=False) if v else ""


made = skipped = 0
for line in sys.stdin:
    vals = line.rstrip("\n").split("\t")
    if len(vals) != len(FIELDS):
        sys.exit(f"unexpected line: {line!r}")
    r = dict(zip(FIELDS, vals))
    owned = r["owned_media"]
    if owned not in EDITION:
        sys.exit(f'{r["albumartist"]} - {r["album"]}: owned_media is {owned!r}')
    # Edition-level fields only when the matched edition is the one owned.
    edition_match = bool(EDITION[owned].fullmatch(r["media"]))
    name = BAD.sub("", f'{r["albumartist"]} - {r["album"]} ({LABEL[owned]})')
    name = re.sub(r"\s+", " ", name).strip()
    path = out_dir / f"{name}.md"
    if path.exists():
        skipped += 1
        continue
    year = r["original_year"] if r["original_year"] not in ("", "0") else ""
    body = "\n".join([
        "---",
        f'artist: {y(r["albumartist"])}',
        f'album: {y(r["album"])}',
        f"year: {year}",
        f"format: {owned}",
        "source:",
        "pressing:",
        f'label: {y(r["label"]) if edition_match else ""}',
        f'catno: {y(r["catalognum"]) if edition_match else ""}',
        "condition:",
        "sleeve:",
        "acquired:",
        f'mbid: {r["mb_albumid"] if edition_match else ""}',
        f'releasegroup: {r["mb_releasegroupid"]}',
        "discogs:",
        "---",
        "",
        "## Notes",
        "",
    ])
    made += 1
    if write:
        path.write_text(body)
    else:
        print(("" if edition_match else "[other edition matched] ") + path.name)

print(f"{'wrote' if write else 'would write'} {made}, skipped {skipped} existing",
      file=sys.stderr)
