"""Write the installer of a mod the way Mod Organizer 2 and Vortex read it

A release folder holds folders of files and fomod/ModuleConfig.xml, which tells the mod manager what to ask
the player and which folders each answer installs. This module writes that file and fomod/info.xml from a plain
description:
    Option   one answer: the folder it installs, the flag it sets, whether it is the one picked at first
    Group    one question: one answer of several, or any number of them
    Step     one page of questions, shown always or only while a flag has a value
    Folder   a folder installed without a question, always or only while a flag has a value
check() reads the written installer back and tells every folder it names that the release does not have
picked() tells what a set of answers installs, the way a mod manager works it out, for checking a release
An installer needs at least one step, a mod that asks nothing shows one page with a single required answer.
FOMOD Plus, the installer many players put into Mod Organizer 2 in place of its own, took Mod Organizer down on
an installer with no step until its fix of 2025-08-30
"""

from dataclasses import dataclass, field
from pathlib import Path
from xml.etree import ElementTree

from common import dll

ONE_OF = "SelectExactlyOne"
ANY_OF = "SelectAny"
ALL_OF = "SelectAll"
SCHEMA = "http://qconsulting.ca/fo3/ModConfig5.0.xsd"
XSI = "http://www.w3.org/2001/XMLSchema-instance"
# an answer that installs nothing still has to do something for the installer, it sets this flag
NOTHING = ("nothing", "chosen")
# the two states of a plugin that is not at work in the load order
NOT_ACTIVE = ("Missing", "Inactive")


@dataclass(frozen=True)
class Option:
    name: str
    description: str
    folder: str | None = None
    flag: tuple[str, str] | None = None
    picked: bool = False
    required: bool = False
    # Plugins of the load order, as "SkyUI_SE.esp". The answer is the one picked at first when all of them
    # are active, or, for picked_without, when any of them is not
    picked_with: tuple[str, ...] = ()
    picked_without: tuple[str, ...] = ()
    image: str | None = None


@dataclass(frozen=True)
class Group:
    name: str
    options: tuple[Option, ...]
    kind: str = ONE_OF


@dataclass(frozen=True)
class Step:
    name: str
    groups: tuple[Group, ...]
    shown_while: tuple[str, str] | None = None


@dataclass(frozen=True)
class Folder:
    source: str
    installed_while: tuple[str, str] | None = None


@dataclass(frozen=True)
class Installer:
    name: str
    author: str
    version: str
    website: str
    description: str
    folders: tuple[Folder, ...]
    steps: tuple[Step, ...] = field(default=())
    image: str | None = None


def child(parent: ElementTree.Element, tag: str, text: str | None = None, **attributes: str) -> ElementTree.Element:
    made = ElementTree.SubElement(parent, tag, attributes)
    made.text = text
    return made


def files(parent: ElementTree.Element, folder: str) -> None:
    child(child(parent, "files"), "folder", source=folder, destination="", priority="0")


def flag_test(parent: ElementTree.Element, flag: tuple[str, str]) -> None:
    child(parent, "flagDependency", flag=flag[0], value=flag[1])


def kind_of(parent: ElementTree.Element, option: Option) -> None:
    told = child(parent, "typeDescriptor")
    if option.required:
        child(told, "type", name="Required")
        return
    if not (option.picked_with or option.picked_without):
        child(told, "type", name="Recommended" if option.picked else "Optional")
        return
    by_plugins = child(told, "dependencyType")
    child(by_plugins, "defaultType", name="Optional")
    pattern = child(child(by_plugins, "patterns"), "pattern")
    if option.picked_with:
        needed = child(pattern, "dependencies", operator="And")
        for plugin in option.picked_with:
            child(needed, "fileDependency", file=plugin, state="Active")
    else:
        needed = child(pattern, "dependencies", operator="Or")
        for plugin in option.picked_without:
            for state in NOT_ACTIVE:
                child(needed, "fileDependency", file=plugin, state=state)
    child(pattern, "type", name="Recommended")


def module_config(installer: Installer) -> ElementTree.Element:
    root = ElementTree.Element("config", {f"{{{XSI}}}noNamespaceSchemaLocation": SCHEMA})
    child(root, "moduleName", installer.name)
    if installer.image:
        child(root, "moduleImage", path=installer.image)

    always = child(root, "requiredInstallFiles")
    for folder in installer.folders:
        if folder.installed_while is None:
            child(always, "folder", source=folder.source, destination="", priority="0")

    steps = child(root, "installSteps", order="Explicit")
    for step in installer.steps:
        page = child(steps, "installStep", name=step.name)
        if step.shown_while:
            flag_test(child(page, "visible"), step.shown_while)
        groups = child(page, "optionalFileGroups", order="Explicit")
        for group in step.groups:
            options = child(child(groups, "group", name=group.name, type=group.kind), "plugins", order="Explicit")
            for option in group.options:
                answer = child(options, "plugin", name=option.name)
                child(answer, "description", option.description)
                if option.image:
                    child(answer, "image", path=option.image)
                if option.folder:
                    files(answer, option.folder)
                flag = option.flag or (None if option.folder else NOTHING)
                if flag:
                    child(child(answer, "conditionFlags"), "flag", flag[1], name=flag[0])
                kind_of(answer, option)

    by_flags = [folder for folder in installer.folders if folder.installed_while]
    if by_flags:
        patterns = child(child(root, "conditionalFileInstalls"), "patterns")
        for folder in by_flags:
            pattern = child(patterns, "pattern")
            flag_test(child(pattern, "dependencies", operator="And"), folder.installed_while)
            files(pattern, folder.source)
    return root


def info(installer: Installer) -> ElementTree.Element:
    root = ElementTree.Element("fomod")
    for tag, text in (("Name", installer.name), ("Author", installer.author), ("Version", installer.version),
                      ("Website", installer.website), ("Description", installer.description)):
        child(root, tag, text)
    return root


def write(release: Path, installer: Installer) -> None:
    if not installer.steps:
        raise ValueError(f"the installer of {installer.name} has no step, give it one with a single required answer")
    # everything of a release passes here, the paths of the build machine stay out of what players get
    for plugin in release.rglob("*.dll"):
        dll.scrubbed(plugin)
    folder = release / "fomod"
    folder.mkdir(parents=True, exist_ok=True)
    for name, root in (("ModuleConfig.xml", module_config(installer)), ("info.xml", info(installer))):
        ElementTree.indent(root, space="  ")
        # mod managers expect these two files in UTF-16
        (folder / name).write_text('<?xml version="1.0" encoding="UTF-16"?>\n' + ElementTree.tostring(root, encoding="unicode") + "\n", encoding="utf-16")


def check(release: Path) -> list[str]:
    """Every folder and picture the written installer names and the release does not have"""
    root = ElementTree.parse(release / "fomod" / "ModuleConfig.xml").getroot()
    named = [folder.get("source") for folder in root.iter("folder")]
    named += [image.get("path") for tag in ("image", "moduleImage") for image in root.iter(tag)]
    return [name for name in named if not (release / name).exists()]


def picked(installer: Installer, answers: dict[str, list[str]]) -> list[str]:
    """The folders a set of answers installs, in the order a mod manager lays them

    answers names the options taken in each group, by the name of the group. A group that is not named gets
    the options picked at first, in a load order that has the plugins an option asks for. A step that is not
    shown asks nothing
    """
    flags: dict[str, str] = {}
    folders = [folder.source for folder in installer.folders if folder.installed_while is None]
    for step in installer.steps:
        if step.shown_while and flags.get(step.shown_while[0]) != step.shown_while[1]:
            continue
        for group in step.groups:
            taken = answers.get(group.name, [option.name for option in group.options
                                             if option.picked or option.picked_with or option.required or group.kind == ALL_OF])
            for option in group.options:
                if option.name in taken:
                    folders += [option.folder] if option.folder else []
                    flags.update([option.flag] if option.flag else [])
    # a flag no taken option set is empty, as mod managers read it
    folders += [folder.source for folder in installer.folders if folder.installed_while and flags.get(folder.installed_while[0], "") == folder.installed_while[1]]
    return folders
