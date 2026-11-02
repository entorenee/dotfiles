"""Sync 0-10 ratings between MPD stickers and beets.

Songs: the `song` sticker `rating`, written by rmpc and Euphonica, against the
item field `rating`. Albums: Euphonica's `filter` sticker `rating`, keyed by an
MBID filter expression, against the album field `album_rating`.

Each run pulls stickers into beets, then pushes beets back, so a sticker that
differs at the start of a run is a newer client edit. A missing sticker never
clears a beets value: moving a file orphans its sticker by path.
"""

import os
import re
from pathlib import Path

import mpd

from beets import ui
from beets.plugins import BeetsPlugin

SONG_FIELD = "rating"
ALBUM_FIELD = "album_rating"
STICKER = "rating"

# The form Euphonica writes; MPD canonicalises it, so case doesn't matter.
EXPRESSION = re.compile(r'\(MUSICBRAINZ_ALBUMID == "([^"]+)"\)', re.IGNORECASE)


def parse_rating(value):
    try:
        rating = int(value)
    except (TypeError, ValueError):
        return None
    return rating if 0 <= rating <= 10 else None


def album_expression(mbid):
    return f'(MUSICBRAINZ_ALBUMID == "{mbid}")'


def find_stickers(client, kind):
    """Map each URI (or filter expression) to its raw `rating` value."""
    # MPD labels song results `file`, not by the sticker type.
    key = "file" if kind == "song" else kind
    found = {}
    for entry in client.sticker_find(kind, "", STICKER):
        names, stickers = entry[key], entry["sticker"]
        # python-mpd2 only splits results on `file`, so several `filter`
        # results arrive as one entry of parallel lists.
        if isinstance(names, str):
            names, stickers = [names], [stickers]
        for uri, sticker in zip(names, stickers):
            name, _, value = sticker.partition("=")
            if name == STICKER:
                found[uri] = value
    return found


class MpdRatingPlugin(BeetsPlugin):
    def __init__(self):
        super().__init__()
        self.config.add({"host": "localhost", "port": 6600})

    def commands(self):
        cmd = ui.Subcommand("mpdrating", help="sync ratings with MPD stickers")
        cmd.parser.add_option(
            "-n",
            "--dry-run",
            action="store_true",
            help="log intended writes without making them",
        )
        cmd.func = self.run
        return [cmd]

    def run(self, lib, opts, args):
        self.dry_run = opts.dry_run
        # What a dry run would have pulled, so its push doesn't report
        # writing the old beets value back over it.
        self.pulled = set()
        root = Path(self.config["music_root"].as_filename())
        client = self.connect()
        try:
            songs = find_stickers(client, "song")
            albums = {
                expr.lower(): value
                for expr, value in find_stickers(client, "filter").items()
            }
            self.pull_songs(self.index_items(lib, root), songs)
            self.pull_albums(lib, albums)
            self.push_songs(lib, client, root, songs)
            self.push_albums(lib, client, albums)
        finally:
            client.disconnect()

    def connect(self):
        host = self.config["host"].as_str()
        port = self.config["port"].get(int)
        client = mpd.MPDClient()
        try:
            client.connect(host, port)
            with open(self.config["password_file"].as_filename()) as f:
                client.password(f.read().strip())
        except (OSError, mpd.MPDError) as e:
            raise ui.UserError(f"mpdrating: cannot reach MPD at {host}:{port}: {e}")
        return client

    def index_items(self, lib, root):
        items = {}
        for item in lib.items():
            path = Path(os.fsdecode(item.path))
            if path.is_relative_to(root):
                items[path.relative_to(root).as_posix()] = item
        return items

    def pull_songs(self, items, songs):
        for uri, value in songs.items():
            rating = parse_rating(value)
            item = items.get(uri)
            if rating is None:
                self._log.warning("ignoring song rating {!r} on {}", value, uri)
            elif item is None:
                self._log.warning("song rating on {} matches no beets item", uri)
            elif item.get(SONG_FIELD, with_album=False) != rating:
                self._log.info("pull {}: {} = {}", item, SONG_FIELD, rating)
                self.pulled.add(uri)
                if not self.dry_run:
                    item[SONG_FIELD] = rating
                    item.store()

    def pull_albums(self, lib, albums):
        by_mbid = {}
        for album in lib.albums():
            by_mbid.setdefault(album.mb_albumid.lower(), []).append(album)
        for expr, value in albums.items():
            rating = parse_rating(value)
            match = EXPRESSION.fullmatch(expr)
            if rating is None:
                self._log.warning("ignoring album rating {!r} on {}", value, expr)
                continue
            if match is None:
                self._log.warning("album rating on {} is not keyed by MBID", expr)
                continue
            found = by_mbid.get(match.group(1), [])
            if len(found) != 1:
                self._log.warning(
                    "album rating on {} matches {} beets albums", expr, len(found)
                )
            elif found[0].get(ALBUM_FIELD) != rating:
                self._log.info("pull {}: {} = {}", found[0], ALBUM_FIELD, rating)
                self.pulled.add(expr)
                if not self.dry_run:
                    found[0][ALBUM_FIELD] = rating
                    found[0].store()

    def push_songs(self, lib, client, root, songs):
        for item in lib.items(f"{SONG_FIELD}:0..10"):
            path = Path(os.fsdecode(item.path))
            if not path.is_relative_to(root):
                continue
            uri = path.relative_to(root).as_posix()
            rating = str(item[SONG_FIELD])
            if songs.get(uri) != rating and uri not in self.pulled:
                self._log.info("push {}: sticker {} = {}", uri, STICKER, rating)
                if not self.dry_run:
                    try:
                        client.sticker_set("song", uri, STICKER, rating)
                    except mpd.CommandError as e:
                        # Syncthing and an MPD rescan haven't caught up with a
                        # new or moved file. The next run retries.
                        if "No such song" not in str(e):
                            raise
                        self._log.warning("{} is not in MPD yet; not pushed", uri)

    def push_albums(self, lib, client, albums):
        for album in lib.albums(f"{ALBUM_FIELD}:0..10"):
            if not album.mb_albumid:
                self._log.warning("{} has no MBID; not pushed", album)
                continue
            expr = album_expression(album.mb_albumid)
            rating = str(album[ALBUM_FIELD])
            if albums.get(expr.lower()) != rating and expr.lower() not in self.pulled:
                self._log.info("push {}: sticker {} = {}", album, STICKER, rating)
                if not self.dry_run:
                    client.sticker_set("filter", expr, STICKER, rating)
