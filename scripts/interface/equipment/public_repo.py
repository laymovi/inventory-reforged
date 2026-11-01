"""Lay Inventory Reforged out as its own repository, only what the mod is built from, in the same relative places

    python -m interface.equipment.public_repo [folder]

Files come from here, public/ adds the readme, its pictures and the few files that differ outside this project. Nothing in the
folder is ever removed, a file that no longer belongs is only named. The words that shouldn't go public are looked
for in every file of text, the lines are named and it's up to a person what happens to them
"""

import argparse
import re
import shutil
from pathlib import Path

from common.paths import PROJECT

TARGET = PROJECT.parents[1] / "inventory-reforged"
EQUIPMENT = "scripts/interface/equipment"
HERE = PROJECT / EQUIPMENT / "public"
# whole folders, without what's under SKIPPED
FOLDERS = [
    "plugins/equipment-panel/source",
    "plugins/equipment-panel/include",
    "plugins/equipment-panel/package",
    "plugins/cmake/ports",
    "scripts/interface/papyrus-headers",
    f"{EQUIPMENT}/source",
    f"{EQUIPMENT}/overlay",
    f"{EQUIPMENT}/menu",
    f"{EQUIPMENT}/debug",
    f"{EQUIPMENT}/api",
    f"{EQUIPMENT}/tests",
]
FILES = [
    "plugins/build.ps1",
    "plugins/equipment-panel/CMakeLists.txt",
    "plugins/equipment-panel/CMakePresets.json",
    "plugins/equipment-panel/vcpkg.json",
    *(f"plugins/shared/source/{name}" for name in ("Detour.h", "Detour.cpp", "Holders.h", "Holders.cpp", "People.h", "People.cpp", "Places.h", "Places.cpp")),
    "scripts/common/__init__.py",
    "scripts/common/dll.py",
    "scripts/common/pex.py",
    "scripts/common/fomod.py",
    "scripts/interface/swf.py",
    "scripts/interface/mcm.py",
    "scripts/interface/skyui_menu.py",
    *(f"{EQUIPMENT}/{name}.py" for name in ("build", "debug_calls", "icons", "pose", "public_repo", "release", "translations")),
    f"{EQUIPMENT}/archive/readme.txt",
]
# only Know your Skyrim includes this one
SKIPPED = {"Functions.h", "__pycache__"}
ADDED = {
    "README.md": "README.md",
    "README.uk.md": "README.uk.md",
    "compatibilities.md": "compatibilities.md",
    "LICENSE": "LICENSE",
    "gitignore": ".gitignore",
    "gitattributes": ".gitattributes",
    "editorconfig": ".editorconfig",
    "paths.py": "scripts/common/paths.py",
    "papyrus.py": "scripts/interface/papyrus.py",
}
BINARY = {".jpg", ".png", ".gif", ".dds", ".swf", ".pex", ".esp"}
# one pattern a line, this file stays here and never goes out itself
PRIVATE_WORDS = HERE / "private-words.txt"


def laid(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.suffix.lower() in BINARY:
        shutil.copyfile(source, target)
    else:
        target.write_bytes(source.read_bytes().replace(b"\r\n", b"\n"))


def wanted() -> dict[str, Path]:
    files = {name: PROJECT / name for name in FILES}
    for folder in FOLDERS:
        for path in (PROJECT / folder).rglob("*"):
            if path.is_file() and not SKIPPED.intersection(path.parts):
                files[path.relative_to(PROJECT).as_posix()] = path
    # inside the repository itself these are already in their places, its release.py lays the same list
    added = HERE if HERE.is_dir() else None
    files.update({target: (added / name if added else PROJECT / target) for name, target in ADDED.items()})
    for path in ((added or PROJECT) / "licences").iterdir():
        files[f"licences/{path.name}"] = path
    # only the pictures the readmes show go along
    pictures = (added or PROJECT) / "pictures"
    for readme in ("README.md", "README.uk.md"):
        for name in re.findall(r"\(pictures/([^)]+)\)", files[readme].read_text(encoding="utf-8")):
            files[f"pictures/{name}"] = pictures / name
    return files


def private_lines(folder: Path, files: dict[str, Path]) -> list[str]:
    found = []
    private = re.compile("|".join(PRIVATE_WORDS.read_text(encoding="utf-8").split("\n")[:-1]), re.IGNORECASE)
    for name in sorted(files):
        path = folder / name
        if path.suffix.lower() in BINARY or path.name == ADDED["paths.py"].rsplit("/", 1)[-1]:
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").split("\n"), 1):
            if private.search(line):
                found.append(f"{name}:{number}: {line.strip()[:120]}")
    return found


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", nargs="?", type=Path, default=TARGET)
    target = parser.parse_args().folder
    files = wanted()
    for name, source in files.items():
        laid(source, target / name)
    print(f"{len(files)} files in {target}")
    for path in sorted(target.rglob("*")):
        relative = path.relative_to(target)
        if path.is_file() and relative.as_posix() not in files and relative.parts[0] not in (".git", "out", "tools", "game-run") and not {"build", "__pycache__"}.intersection(relative.parts):
            print(f"no longer belongs: {relative.as_posix()}")
    lines = private_lines(target, files)
    print(f"{len(lines)} lines with words that shouldn't go public")
    for line in lines:
        print(f"  {line}")


if __name__ == "__main__":
    main()
