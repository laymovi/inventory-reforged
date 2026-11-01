"""Lay the equipment panel out the way a player gets it, as a folder with an installer for Mod Organizer 2 and
Vortex, and its archive

    python -m interface.equipment.release [--no-archive]

--no-archive lays out the folders only, for a local build between releases: the archive of a released version
stays as it was uploaded

Takes the package python -m interface.equipment.build writes and lays out two folders of out/skyui-equipment/release
  Inventory Reforged for SkyUI   the mod as one folder with the menu, as the installer gives it for its first answer
  installer         what goes into the archive
    core     the SKSE plugin, its ini and the panel script movie, installed always
    menu     the menu in the game drawn by SkyUI itself: the light plugin with its quest and the scripts
    menu-mcmhelper   the same menu drawn by MCM Helper, with its pages, the installer picks it when MCM Helper is there
    options  a folder for each answer of the pages after the menu that changes how the mod starts (PAGES), each with
             one small ini in SKSE/Plugins/InventoryReforged
    fomod    the installer, its picture and a picture of each answer (installer_pictures.py) in fomod/options
    source   what the plugin and the panel are built from. The plugin links CommonLibSSE-NG, which is under
             the GPL 3, so its source goes with every copy
    readme.txt
The archive goes to out/skyui-equipment/InventoryReforged-<version>.zip
"""

import argparse
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image

from common.paths import PROJECT
from interface.equipment import public_repo
from interface.equipment.build import API_TEXT, MCM_HELPER_MENU, PACKAGE, WORK
from common import fomod

NAME = "Inventory Reforged for SkyUI"
FILES = "InventoryReforged"
AS_ONE_FOLDER = WORK / "release" / NAME
RELEASE = WORK / "release" / "installer"
ARCHIVE_TEXTS = PROJECT / "scripts" / "interface" / "equipment" / "archive"
PICTURE_IN_INSTALLER = "fomod/main.jpg"
PICTURE_WIDTH = 960
# each answer's picture (installer_pictures.py), shown beside it in the installer
OPTION_PICTURES = WORK / "installer-pictures"
OPTION_PICTURE = "fomod/options/{}.jpg"
VERSION_LINE = re.compile(rf"project\({FILES} VERSION ([\d.]+)")
SETUP_QUESTION = "Menu in the game"
MENU_FILES = (f"{FILES}.esp", "Scripts")
HELPER = "MCMHelper.esp"
HELPER_PLUGINS = ("SkyUI_SE.esp", HELPER)
MENU_BY_HELPER = "Menu in MCM Helper"
MENU_BY_SKYUI = "Menu in SkyUI"
NO_MENU = "Without the menu"
IN_GAME = ("setup", "menu")
BY_HELPER = ("setup", "mcmhelper")
BY_HAND = ("setup", "ini")


# The pages after the menu set how the mod starts. An answer that changes the start installs a small ini of its own
# into SKSE/Plugins/InventoryReforged/, the plugin reads those over its shipped ini and copies them into the menu's
# file, so the menu shows them and what the player sets there later wins. The first answer of a one-of question is
# how the mod comes and installs nothing, a manual install gets just that
ANSWERS = "options"
ANSWER_FOLDER = Path("SKSE") / "Plugins" / FILES


@dataclass(frozen=True)
class Answer:
    name: str
    description: str
    # section, then the names and values it sets
    sets: dict[str, dict[str, int]] = field(default_factory=dict)
    # the answer picked at first when it isn't the mod as it comes
    recommended: bool = False


@dataclass(frozen=True)
class Question:
    name: str
    answers: tuple[Answer, ...]
    # one of: the first answer is the mod as it comes. Any of: each ticked answer changes the start
    any_of: bool = False
    # any of, ticked at first: a ticked answer is the mod as it comes, an unticked one installs what it sets. The
    # player switches the panel on in a menu and sees what they get, the words tell what they had
    ticked: bool = False


def answer_folder(question: Question, answer: Answer) -> str:
    """The folder of an answer, by its question too: two questions have a Smaller"""
    return re.sub(r"[^a-z0-9]+", "-", f"{question.name} {answer.name}".lower()).strip("-")


def text_size(name: str, percent: int, description: str) -> Answer:
    return Answer(name, description, {"Window": {key: percent for key in ("iNameText", "iWordsText", "iNumbersText", "iQuietText")}})


def slot_off(name: str, key: str) -> Answer:
    return Answer(name, f"Takes the {name.lower()} slot off the panel. What you wear there stays worn.", {"Slots": {key: 0}})


PAGES = {
    "Panel": (
        Question("Character", (
            Answer("In 3D, standing calm", "Your character between the columns of slots, standing straight whatever you did when the menu opened. A drag turns it."),
            Answer("In 3D, in the pose of the moment", "In third person the character keeps the pose it had when the menu opened. In first person it stands either way.", {"Doll": {"iPose": 1}}),
            Answer("No character, slots only", "The columns of slots without the 3D character. The lightest on the video card.", {"Doll": {"bShow": 0}}),
        )),
        Question("Companions", (
            Answer("Tabs over the character", "You and each follower near you get a tab over the character. A click opens that follower's inventory or yours, at a crafting station it shows them for trying gear on. "
                   "May not get along with a mod that also takes over how followers are managed (a follower framework with its own menus, a mod that opens a follower's inventory its own way): if a follower acts up, switch the tabs off in the menu of the mod.",
                   {"Panel": {"bCompanionTabs": 1}}, recommended=True),
            Answer("No tabs", "The panel shows you. A follower shows in a trade with them, as without the mod."),
        )),
        Question("Panel width", (
            Answer("Full width", "The slots and your character take all the room beside the item list."),
            Answer("Narrow", "The panel keeps further from the list, for a UI skin or a screen where the slots lay over the rows.", {"Panel": {"iPanelSize": 88, "iPanelShift": 6}}),
            Answer("Narrower", "The panel keeps furthest from the list.", {"Panel": {"iPanelSize": 76, "iPanelShift": 12}}),
        )),
        Question("The panel in other menus", (
            Answer("Magic menu", "Your character between the slots of your hands and your voice beside SkyUI's magic menu. Untick it and the magic menu stays as SkyUI has it, a list of spells.", {"Panel": {"bMagicMenu": 0}}),
            Answer("Crafting stations", "Your character and your slots beside the recipes of a forge, a workbench, a tanning rack, a grindstone or an enchanter, and gear tried on for show. Untick it and the stations stay as SkyUI has them, a list of recipes.", {"Panel": {"bCraftingMenu": 0}}),
            Answer("Trades with followers", "A follower in the panel during a trade with them: what they wear, hidden pieces, their outfit. Untick it and a trade stays a plain container of two lists.", {"Panel": {"bFollowers": 0}}),
        ), any_of=True, ticked=True),
        Question("Leave out", (
            Answer("Character drawer", "No tab at the feet of your character that pulls up your numbers.", {"Window": {"bHeroStats": 0}}),
            Answer("Sliders button", "No sliders button in the bottom bar of the item menus, for a UI skin where it gets in the way. What it opens is all in the menu of the mod.", {"Panel": {"bLookButton": 0}}),
        ), any_of=True),
    ),
    "Slots": (
        Question("Slots to leave off the panel", tuple(slot_off(name, key) for name, key in (
            ("Right hand", "bShowRight"), ("Left hand", "bShowLeft"), ("Ammo", "bShowAmmo"), ("Amulet", "bShowAmulet"), ("Ring", "bShowRing"),
            ("Head", "bShowHead"), ("Body", "bShowBody"), ("Hands", "bShowHands"), ("Feet", "bShowFeet"), ("Other", "bShowOther"))), any_of=True),
        Question("Slot pictures", (
            Answer("3D models", "The slots show 3D models of what you wear."),
            Answer("Flat signs", "Flat signs in place of the models, a little lighter on the video card.", {"Slots": {"bModels": 0}}),
        )),
    ),
    "Item window": (
        Question("Text size", (
            Answer("As it comes", "The words of the item window at their own size."),
            text_size("Smaller", 90, "The words of the item window at nine tenths of their size."),
            text_size("Larger", 115, "The words of the item window a little larger: the name, the effects and descriptions, the numbers, the small lines."),
            text_size("Large", 130, "The words of the item window about a third larger."),
            text_size("Largest", 150, "The words of the item window half as large again, for a big screen seen from afar."),
        )),
        Question("Window size", (
            Answer("As it comes", "About half the list and never less than four tenths of the screen's height."),
            Answer("Smaller", "The item window and its model smaller.", {"Window": {"iSize": 85}}),
            Answer("Larger", "The item window and its model larger.", {"Window": {"iSize": 120}}),
        )),
        Question("The window comes up", (
            Answer("At once", "The window comes up over a row as the pointer gets there."),
            Answer("After a pause", "The window comes up once the pointer rests on a row a moment.", {"Window": {"iPopUp": 1}}),
            Answer("Never, the UI's own card", "No window over the rows, the card and model stay where SkyUI or your UI skin puts them. A click on a slot and Details in a row's menu still bring the window up.", {"Window": {"iPopUp": 2}}),
        )),
        Question("Lines of the window", (
            Answer("No combat numbers", "Without swing time, DPS, reach, stagger and the share of a hit armor stops.", {"Window": {"bStats": 0}}),
            Answer("No quest line", "Without the line that says what a quest wants with the item.", {"Window": {"bQuestLine": 0}}),
            Answer("No mod line", "Without the line that names the plugin an item comes from.", {"Window": {"bModOrigin": 0}}),
            Answer("Body slots of worn pieces", "Adds a small grey line with the body slots a piece takes, like Slots 32, 46.", {"Window": {"bSlotNumbers": 1}}),
        ), any_of=True),
        Question("Made from", (
            Answer("Every part of the recipe", "The parts of its forge recipe in the window's top left corner, like Steel Ingot (3) and Leather Strips (3). An item with no recipe shows its main material."),
            Answer("The main material", "Just the material in that corner, like Steel Plate or Ebony.", {"Lines": {"iMadeOf": 1}}),
            Answer("Nothing", "The window's top left corner stays empty.", {"Lines": {"iMadeOf": 0}}),
        )),
    ),
    "List": (
        Question("Pictures in the list", (
            Answer("Pictures of the items", "Each row of the inventory, a chest or a shop shows a real picture of its item in place of the flat sign. They are made from your own models, once for each kind of item, as a save loads with a bar on the loading screen, so that first load takes a little longer. "
                   "Takes a little more memory and disk space: about 20 KB on disk for each kind of item, and a few hundred MB of memory in the game that makes them."),
            Answer("Flat signs", "The flat signs of SkyUI or your UI skin. No pictures are made.", {"Slots": {"bRowModels": 0}}),
        )),
        Question("Marks to leave out", (
            Answer("Quest marks", "No sign after the name of what a quest wants.", {"List": {"bQuestMarks": 0}}),
            Answer("New item dots", "No dot on what you got since you last closed the inventory.", {"List": {"bNewMarks": 0}}),
            Answer("Compare arrows", "No arrows that compare an item with what you wear.", {"List": {"bArrows": 0, "bEqualSign": 0}}),
            Answer("Junk marks", "No junk marks and no junk key.", {"List": {"bJunk": 0}}),
            Answer("Weight warnings", "No red weight on a row that would slow you in a chest or a shop.", {"List": {"bWeightWarnings": 0}}),
        ), any_of=True),
        # slot badges are off as the mod comes, a player switches them on here or in the game
        Question("Marks to add", (
            Answer("Slot badges", "The sign of its slot in the first column of a row you could wear, where a worn row has the game's own mark.", {"List": {"bBadges": 1}}),
        ), any_of=True),
        Question("Subcategories", (
            Answer("Strip under weapons and apparel", "One handed, two handed, light, heavy, head and so on under the categories."),
            Answer("No strip", "The categories of SkyUI or your UI skin alone.", {"List": {"bSubcategories": 0}}),
        )),
    ),
}

def version() -> str:
    return VERSION_LINE.search((PROJECT / "plugins" / "equipment-panel" / "CMakeLists.txt").read_text(encoding="utf-8")).group(1)


def installer() -> fomod.Installer:
    setup = fomod.Group(SETUP_QUESTION, (
        fomod.Option(
            MENU_BY_HELPER,
            "Installs the menu of the panel in System, Mod Configuration, drawn by MCM Helper. Picked when MCM Helper is "
            f"active. Adds the light plugin {FILES}.esp, it takes no place in your load order. A change in the menu holds "
            "the next time you open the inventory.",
            flag=BY_HELPER, picked_with=HELPER_PLUGINS, image=option_picture("setup-menu-in-mcm-helper")),
        fomod.Option(
            MENU_BY_SKYUI,
            "Installs the menu of the panel in System, Mod Configuration, drawn by SkyUI itself, no MCM Helper needed. "
            f"Picked when MCM Helper isn't there. Adds the light plugin {FILES}.esp, it takes no place in your load order. "
            "Both menus keep what you set in the same file, changing from one to the other keeps it.",
            flag=IN_GAME, picked_without=(HELPER,), image=option_picture("setup-menu-in-skyui")),
        fomod.Option(
            NO_MENU,
            f"Installs no plugin at all. The panel works the same, its switches live in Data/SKSE/Plugins/{FILES}.ini.",
            flag=BY_HAND, image=option_picture("setup-without-the-menu")),
    ))
    return fomod.Installer(
        name=NAME,
        author="laymovi",
        version=version(),
        website="",
        description="Your character in 3D beside the SkyUI inventory, with a slot for everything you wear: click, drag, hide, compare and inspect.",
        folders=(fomod.Folder("core"), fomod.Folder("menu", installed_while=IN_GAME), fomod.Folder("menu-mcmhelper", installed_while=BY_HELPER)) + unticked_folders(),
        steps=(fomod.Step("Setup", (setup,)),) + tuple(fomod.Step(page, tuple(group_of(question) for question in questions)) for page, questions in PAGES.items()),
        image=PICTURE_IN_INSTALLER if main_picture().exists() else None,
    )


def ticked_flag(question: Question, answer: Answer) -> tuple[str, str]:
    """the flag a ticked answer sets, its ini installs while the flag is missing"""
    return (f"on-{answer_folder(question, answer)}", "on")


def group_of(question: Question) -> fomod.Group:
    options = []
    recommended = any(answer.recommended for answer in question.answers)
    for at, answer in enumerate(question.answers):
        name = answer_folder(question, answer)
        if question.ticked:
            note = " The mod comes so. You can change it later in the menu of the mod."
            options.append(fomod.Option(answer.name, answer.description + note, flag=ticked_flag(question, answer), picked=True, image=option_picture(name)))
            continue
        first = not question.any_of and (answer.recommended if recommended else at == 0)
        note = " The mod comes so." if not question.any_of and not answer.sets else ""
        note += " You can change it later in the menu of the mod." if answer.sets else ""
        options.append(fomod.Option(answer.name, answer.description + note, folder=f"{ANSWERS}/{name}" if answer.sets else None, picked=first, image=option_picture(name)))
    return fomod.Group(question.name, tuple(options), kind=fomod.ANY_OF if question.any_of else fomod.ONE_OF)


# the ini of an unticked answer of a ticked question installs while its flag is missing
def unticked_folders() -> tuple[fomod.Folder, ...]:
    return tuple(fomod.Folder(f"{ANSWERS}/{answer_folder(question, answer)}", installed_while=(ticked_flag(question, answer)[0], ""))
                 for questions in PAGES.values() for question in questions if question.ticked for answer in question.answers)


def option_picture(name: str) -> str | None:
    return OPTION_PICTURE.format(name) if (OPTION_PICTURES / f"{name}.jpg").exists() else None


# every name an answer sets is one the shipped ini has, a wrong one would install and do nothing
def unknown_names() -> list[str]:
    known = set()
    section = ""
    for line in (PACKAGE / ANSWER_FOLDER.parent / f"{FILES}.ini").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
        elif "=" in line and not line.startswith(";"):
            known.add(f"{section}:{line.split('=')[0].strip()}")
    return [f"{question.name}, {answer.name}: {section}:{name}" for questions in PAGES.values() for question in questions for answer in question.answers
            for section, values in answer.sets.items() for name in values if f"{section}:{name}" not in known]


# each answer that changes the start as a folder with its small ini
def lay_answers() -> None:
    for questions in PAGES.values():
        for question in questions:
            for answer in (answer for answer in question.answers if answer.sets):
                name = answer_folder(question, answer)
                target = RELEASE / ANSWERS / name / ANSWER_FOLDER / f"{name}.ini"
                target.parent.mkdir(parents=True, exist_ok=True)
                lines = [f"; {question.name}: {answer.name}, picked in the installer"]
                for section, values in answer.sets.items():
                    lines += [f"[{section}]"] + [f"{name} = {value}" for name, value in values.items()]
                target.write_text("\n".join(lines) + "\n", encoding="utf-8")


def lay_out() -> None:
    shutil.rmtree(AS_ONE_FOLDER, ignore_errors=True)
    shutil.copytree(PACKAGE, AS_ONE_FOLDER)
    # one folder for a profile with MCM Helper, as the installer lays it out when MCM Helper is active
    shutil.copytree(MCM_HELPER_MENU, AS_ONE_FOLDER, dirs_exist_ok=True)
    shutil.rmtree(RELEASE, ignore_errors=True)
    for file in (path for path in PACKAGE.rglob("*") if path.is_file()):
        inside = file.relative_to(PACKAGE)
        # the script of the plugin's calls is the API other mods call, it goes with every way of installing
        menu = inside.parts[0] in MENU_FILES and inside.name != f"{FILES}.pex"
        target = RELEASE / ("menu" if menu else "core") / inside
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, target)
    shutil.copytree(MCM_HELPER_MENU, RELEASE / "menu-mcmhelper")
    lay_answers()
    # the API for other mods is the last part of the readme, written once in api/
    readme = (ARCHIVE_TEXTS / "readme.txt").read_text(encoding="utf-8").rstrip("\n")
    api = API_TEXT.read_text(encoding="utf-8")
    (RELEASE / "readme.txt").write_text(f"{readme}\n\n{api}", encoding="utf-8")
    public_repo.laid(public_repo.wanted()["compatibilities.md"], RELEASE / "compatibilities.md")
    lay_source()
    if OPTION_PICTURES.is_dir():
        (RELEASE / OPTION_PICTURE).parent.mkdir(parents=True, exist_ok=True)
        for picture in OPTION_PICTURES.glob("*.jpg"):
            shutil.copyfile(picture, RELEASE / OPTION_PICTURE.format(picture.stem))
    if main_picture().exists():
        shown = RELEASE / PICTURE_IN_INSTALLER
        shown.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(main_picture()) as picture:
            height = round(picture.height * PICTURE_WIDTH / picture.width)
            picture.convert("RGB").resize((PICTURE_WIDTH, height), Image.LANCZOS).save(shown, quality=88)


def main_picture() -> Path:
    return public_repo.wanted()["pictures/01-panel.jpg"]


def lay_source() -> None:
    """The same files as the public repository without the readme's pictures, the archive's copy builds the same way"""
    for name, source in public_repo.wanted().items():
        if not name.startswith("pictures/"):
            public_repo.laid(source, RELEASE / "source" / name)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--no-archive", action="store_true", help="the folders only, the archive of this version is left alone")
    arguments = parser.parse_args()
    if wrong := unknown_names():
        raise SystemExit(f"answers of the installer set names the shipped ini hasn't got: {wrong}")
    lay_out()
    told = installer()
    fomod.write(RELEASE, told)
    missing = fomod.check(RELEASE)
    for way in (MENU_BY_HELPER, MENU_BY_SKYUI, NO_MENU):
        answers = {SETUP_QUESTION: [way]}
        folders = fomod.picked(told, answers)
        missing += [folder for folder in folders if not (RELEASE / folder).is_dir()]
        print(f"{way}: {', '.join(folders)}")
    # a menu left unticked gets the ini that switches its panel off, all ticked install none of them
    unticked = fomod.picked(told, {"The panel in other menus": []})
    ticked = fomod.picked(told, {})
    print(f"menus unticked: {', '.join(folder for folder in unticked if folder not in ticked)}")
    if missing:
        raise SystemExit(f"the installer names what the release does not have: {missing}")
    files = sum(1 for file in RELEASE.rglob("*") if file.is_file())
    print(f"{files} files in {RELEASE}")
    if arguments.no_archive:
        print(f"no archive written, {FILES}-{told.version}.zip left as it was")
        return
    archive = shutil.make_archive(str(WORK / f"{FILES}-{told.version}"), "zip", RELEASE)
    print(f"{archive}: {Path(archive).stat().st_size} bytes")


if __name__ == "__main__":
    main()
