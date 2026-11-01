"""The compiler leaves the full path of every source file and of the debug symbols in a plugin. Only the file's name
stays, its place is filled with zeros, so the DLL keeps its size and every string keeps its address"""

import os
import re
from pathlib import Path

# A path can follow any data byte, also one that looks like a letter. Only the forward slash needs the check, http:/ isn't a path
PATH = re.compile(rb"(?:(?<![A-Za-z0-9])[A-Za-z]:/|[A-Za-z]:\\)[\x20-\x7e]{1,300}?\x00")
WIDE_PATH = re.compile(rb"(?:(?<![A-Za-z0-9]\x00)[A-Za-z]\x00:\x00/\x00|[A-Za-z]\x00:\x00\\\x00)(?:[\x20-\x7e]\x00){1,300}?\x00\x00")
SEPARATOR = re.compile(rb"[\\/]")
SYSTEM = (b"c:\\windows", b"c:/windows")


def short(found: re.Match) -> bytes:
    whole = found.group(0)
    if whole.lower().startswith(SYSTEM):
        return whole
    name = SEPARATOR.split(whole[:-1])[-1]
    return name + b"\x00" * (len(whole) - len(name))


def short_wide(found: re.Match) -> bytes:
    whole = found.group(0)
    text = whole[:-2].decode("utf-16-le")
    if text.lower().startswith(("c:\\windows", "c:/windows")):
        return whole
    name = re.split(r"[\\/]", text)[-1].encode("utf-16-le")
    return name + b"\x00" * (len(whole) - len(name))


def scrubbed_bytes(data: bytes) -> bytes:
    return WIDE_PATH.sub(short_wide, PATH.sub(short, data))


def scrubbed(path: Path) -> None:
    """A file of a package may be hard linked elsewhere, so it's replaced and never written through"""
    fresh = path.with_name(path.name + ".scrubbed")
    fresh.write_bytes(scrubbed_bytes(path.read_bytes()))
    os.replace(fresh, path)
