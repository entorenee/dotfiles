"""Write one Releases/ note per vinyl record in the Discogs collection.
Reads the collection with the token in $DISCOGS_TOKEN_FILE. Fills mbid when
MusicBrainz links the pressing, unless --no-mb. Skips records that already
have a note. Dry-run unless --write, which also saves the raw responses to
<snapshot dir>/<date>.json.
Usage: discogs-to-vault.py <Releases dir> <snapshot dir> [--write] [--no-mb]
       [--wants <Wants dir>]"""

import argparse
import datetime
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.discogs.com"
MB = "https://musicbrainz.org/ws/2/url"
UA = "collection-notes/1.0"
BAD = re.compile(r'[\\/:*?"<>|#^\[\]]')
RELEASE_ID = re.compile(r"/release/(\d+)")
# Discogs disambiguates same-named artists with a " (2)" suffix.
DISAMBIG = re.compile(r" \(\d+\)$")


def y(v):
    # JSON strings are valid YAML double-quoted scalars.
    return json.dumps(v, ensure_ascii=False) if v else ""


TOKEN = None


def read_token():
    path = os.environ.get("DISCOGS_TOKEN_FILE", "")
    try:
        return Path(path).read_text().strip()
    except OSError as e:
        sys.exit(f"cannot read DISCOGS_TOKEN_FILE ({path!r}): {e}")


def get(url, retried=False):
    global TOKEN
    TOKEN = TOKEN or read_token()
    req = urllib.request.Request(url, headers={
        "User-Agent": UA, "Authorization": f"Discogs token={TOKEN}"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.load(resp)
            # The limit is a 60s moving window.
            if resp.headers.get("X-Discogs-Ratelimit-Remaining") == "0":
                time.sleep(60)
            return data
    except urllib.error.HTTPError as e:
        if e.code == 401:
            sys.exit("Discogs rejected the token in DISCOGS_TOKEN_FILE (401)")
        if e.code == 429 and not retried:
            time.sleep(60)
            return get(url, retried=True)
        sys.exit(f"{url}: HTTP {e.code}")


def fetch():
    user = get(f"{API}/oauth/identity")["username"]
    fields = get(f"{API}/users/{user}/collection/fields")["fields"]
    releases = []
    url = f"{API}/users/{user}/collection/folders/0/releases?per_page=100"
    while url:
        page = get(url)
        releases += page["releases"]
        url = page["pagination"]["urls"].get("next")
    return user, fields, releases


def field_ids(fields):
    by_name = {f["name"].lower(): f["id"] for f in fields}
    ids = {}
    for key, name in [("condition", "media condition"),
                      ("sleeve", "sleeve condition"), ("notes", "notes")]:
        if name in by_name:
            ids[key] = by_name[name]
        else:
            print(f"no Discogs field {name!r}; have: "
                  + ", ".join(f["name"] for f in fields), file=sys.stderr)
    return ids


def artist_name(artists):
    out = ""
    for i, a in enumerate(artists):
        out += DISAMBIG.sub("", a.get("anv") or a["name"])
        if i < len(artists) - 1:
            join = a.get("join") or ","
            out += ", " if join == "," else f" {join} "
    return out


def pressing(formats):
    parts = []
    for f in formats:
        if len(formats) > 1:
            parts.append(f'{f.get("qty", "1")}x{f["name"]}')
        parts += f.get("descriptions", [])
        if f.get("text"):
            parts.append(f["text"])
    return ", ".join(parts)


def normalize(item, ids):
    b = item["basic_information"]
    notes = {n["field_id"]: n["value"] for n in item.get("notes", [])}
    label = b["labels"][0] if b.get("labels") else {}
    return {
        "release_id": b["id"],
        "master_id": b.get("master_id") or 0,
        "artist": artist_name(b["artists"]),
        "album": b["title"],
        "year": b.get("year") or "",
        "pressing": pressing(b["formats"]),
        "label": label.get("name", ""),
        "catno": label.get("catno", ""),
        "condition": notes.get(ids.get("condition"), ""),
        "sleeve": notes.get(ids.get("sleeve"), ""),
        "notes": notes.get(ids.get("notes"), ""),
        "is_vinyl": any(f["name"] == "Vinyl" for f in b["formats"]),
        "tags": [],
    }


def mb_releases(release_id, retried=False):
    """MusicBrainz releases linked to a Discogs release, or None if MB is down."""
    resource = f"https://www.discogs.com/release/{release_id}"
    url = f"{MB}?resource={resource}&inc=release-rels&fmt=json"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    time.sleep(1.1)  # MusicBrainz allows 1 request/s.
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            rels = json.load(resp).get("relations", [])
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return []
        if e.code == 503 and not retried:
            time.sleep(2)
            return mb_releases(release_id, retried=True)
        return None
    except urllib.error.URLError:
        return None
    return sorted({r["release"]["id"] for r in rels if "release" in r})


def frontmatter(path):
    """Raw `key: value` strings between the first two `---` lines."""
    lines = path.read_text().splitlines()
    fm = {}
    if not lines or lines[0] != "---":
        return fm
    for line in lines[1:]:
        if line == "---":
            break
        key, sep, value = line.partition(":")
        if sep and key not in fm:
            fm[key] = value.strip()
    return fm


def vault_index(directory):
    """Map Discogs release ID → note path, read from each note's frontmatter."""
    index = {}
    for path in directory.glob("*.md"):
        m = RELEASE_ID.search(frontmatter(path).get("discogs", ""))
        if m:
            index[int(m.group(1))] = path
    return index


def note(r):
    lines = [
        "---",
        f'artist: {y(r["artist"])}',
        f'album: {y(r["album"])}',
        f'year: {r["year"]}',
        "format: vinyl",
        "source:",
        f'pressing: {y(r["pressing"])}',
        f'label: {y(r["label"])}',
        f'catno: {y(r["catno"])}',
        f'condition: {y(r["condition"])}',
        f'sleeve: {y(r["sleeve"])}',
        # Discogs' date_added is when it was catalogued, not bought; a blank
        # date is what flags the note for review.
        "acquired:",
        "price:",
        f'mbid: {r.get("mbid", "")}',
        "releasegroup:",
        f'discogs: https://www.discogs.com/release/{r["release_id"]}',
        "---",
        "",
        "## Notes",
        "",
    ]
    if r["notes"].strip():
        lines += [r["notes"].strip(), ""]
    return "\n".join(line.rstrip() for line in lines)


def filename(r, suffix=""):
    name = BAD.sub("", f'{r["artist"]} - {r["album"]} (Vinyl{suffix})')
    return re.sub(r"\s+", " ", name).strip() + ".md"


def run_collection(args):
    out_dir, snap_dir, write = args.out_dir, args.snap_dir, args.write
    user, fields, items = fetch()
    ids = field_ids(fields)
    records = [normalize(i, ids) for i in items]
    index = vault_index(out_dir)

    seen, todo = set(), []
    skipped = not_vinyl = 0
    for r in records:
        if not r["is_vinyl"]:
            not_vinyl += 1
            continue
        rid = r["release_id"]
        if rid in seen:
            print(f"warning: {rid} is in the collection twice; one note",
                  file=sys.stderr)
            continue
        seen.add(rid)
        if rid in index:
            skipped += 1
            continue
        todo.append(r)

    # Masters give the original year; fetched only for records about to be written.
    masters = {}
    for r in todo:
        mid = r["master_id"]
        if mid and mid not in masters:
            masters[mid] = get(f"{API}/masters/{mid}")
        if mid and masters[mid].get("year"):
            r["year"] = masters[mid]["year"]

    for r in [] if args.no_mb else todo:
        found = mb_releases(r["release_id"])
        if found is None:
            r["tags"].append("MusicBrainz unavailable")
        elif len(found) == 1:
            r["mbid"] = found[0]
        elif found:
            r["tags"].append(f"{len(found)} MusicBrainz matches: {', '.join(found)}")
        else:
            r["tags"].append("no MusicBrainz match")

    made = 0
    taken = set()
    for r in todo:
        path = out_dir / filename(r)
        # Only a note linked to another pressing proves this is a second one.
        if path.exists() and path.name not in taken and path not in index.values():
            print(f"skipped, note exists without this discogs link: {path.name}",
                  file=sys.stderr)
            continue
        if path.exists() or path.name in taken:
            path = out_dir / filename(r, f", {r['catno'] or r['release_id']}")
            if path.exists() or path.name in taken:
                print(f"skipped, name collision: {path.name}", file=sys.stderr)
                continue
        taken.add(path.name)
        made += 1
        tags = "".join(f"[{t}] " for t in r["tags"])
        if write:
            path.write_text(note(r))
            if tags:
                print(f"{tags}{path.name}", file=sys.stderr)
        else:
            print(tags + path.name)

    on_discogs = {r["release_id"] for r in records}
    gone = sorted(p.name for rid, p in index.items() if rid not in on_discogs)
    for name in gone:
        print(f"in vault, not on Discogs: {name}", file=sys.stderr)

    if write:
        snap_dir.mkdir(parents=True, exist_ok=True)
        snap = snap_dir / f"{datetime.date.today().isoformat()}.json"
        snap.write_text(json.dumps({"username": user, "fields": fields,
                                    "releases": items, "masters": masters},
                                   ensure_ascii=False, indent=1))
        print(f"snapshot: {snap}", file=sys.stderr)

    print(f"{'wrote' if write else 'would write'} {made}, skipped {skipped} existing,"
          f" {not_vinyl} not vinyl, {len(gone)} in vault not on Discogs",
          file=sys.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out_dir", type=Path)
    ap.add_argument("snap_dir", type=Path)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--no-mb", action="store_true")
    ap.add_argument("--wants", type=Path, default=None)
    args = ap.parse_args()
    run_collection(args)


if __name__ == "__main__":
    main()
