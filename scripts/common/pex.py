"""A compiled Papyrus script carries the path of its source, the user and the computer that compiled it, this keeps
them out of what goes to players"""

import os
import struct
from pathlib import Path

# magic, two version bytes, the game, the compile time
HEADER_SIZE = 16
WORD_COUNT = 3
AUTHOR = "laymovi"


def word(text: str) -> bytes:
    data = text.encode("latin1")
    return struct.pack(">H", len(data)) + data


def scrubbed(path: Path) -> None:
    """The source's name alone and the author in place of the user and the computer. A file of a package may be hard
    linked elsewhere, so it's replaced and never written through"""
    data = path.read_bytes()
    at = HEADER_SIZE
    words = []
    for _ in range(WORD_COUNT):
        size = struct.unpack_from(">H", data, at)[0]
        words.append(data[at + 2:at + 2 + size].decode("latin1"))
        at += 2 + size
    source = words[0].replace("\\", "/").rsplit("/", 1)[-1]
    fresh = path.with_name(path.name + ".scrubbed")
    fresh.write_bytes(data[:HEADER_SIZE] + word(source) + word(AUTHOR) + word(AUTHOR) + data[at:])
    os.replace(fresh, path)
