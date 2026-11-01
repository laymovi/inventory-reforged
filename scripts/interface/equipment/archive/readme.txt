Inventory Reforged for SkyUI 1.7.0
====================================

Your character in 3D beside the SkyUI inventory, with a slot for everything you wear and real pictures of your items
in the rows. The same panel comes to a follower's trade, the magic menu with the slots of your hands and your voice,
and crafting stations, and chests and shops get its item card, row menus, pictures and junk. Mouse, keyboard and
gamepad.

Requirements
- Skyrim Special Edition or Anniversary Edition with SKSE64
- Address Library for SKSE Plugins
- SkyUI
- Recommended: Know your Skyrim, a browser of items, people and quests that opens in the panel
- With Dear Diary, Vel'dun UI and other skins on the old SkyUI 5.2 on game 1.6.1130 or later: Widescreen Scale
  Removed, as those skins ask, or the game squeezes them
- Built and tested on games 1.7.104 (SKSE64 2.3.1), 1.6.1170 (SKSE64 2.2.6) and 1.5.97 (SKSE64 2.0.20), with Address
  Library 13 (All in One) and SkyUI 6.11

Install with a mod manager
Install the archive with Mod Organizer 2 or Vortex. The installer asks about the menu:
- Menu in MCM Helper: picked when MCM Helper is active, installs the light plugin InventoryReforged.esp with the menu
- Menu in SkyUI: picked when MCM Helper isn't there, the same menu drawn by SkyUI itself. Both keep the settings in one file
- Without the menu: installs no plugin. The switches live in Data/SKSE/Plugins/InventoryReforged.ini
The pages after it set how the mod starts, each answer can be changed later in the menu:
- Panel: the character in 3D, in the pose of the moment or none, companion tabs (picked at first, a mod that also
  manages followers may not get along with them), the width of the panel, and the menus the panel comes to: the
  magic menu, crafting stations and trades with followers, untick one to keep it as it was. The character drawer and
  the sliders button can be left out
- Slots: slots to leave off the panel, 3D models or flat signs. No character and all ten slots left off gives the list
  and the item window with no panel beside them
- Item window: text size, window size, when the window comes up, lines to leave out or add, and Made from in its top
  left corner: every part of the recipe, the main material or nothing
- List: pictures of the items or flat signs, quest marks, new item dots, compare arrows, junk marks and weight warnings to leave out, slot badges to add
  (off as the mod comes), the subcategory strip
An answer that changes the start puts a small ini into Data/SKSE/Plugins/InventoryReforged/. At the start of a game
it goes into the menu's file, so the menu shows it. What you set in the menu stays as you set it.

Install by hand
Copy the content of the folder "core" into the Data folder of the game. For the menu copy the content of
"menu" too and enable InventoryReforged.esp. The mod starts as it comes, a folder of "options" copied the same way
sets one answer of the installer.

Pictures in the list
Each kind of item gets its picture once, made from your own models and textures. What you and your followers carry is
made as a save loads, with a bar on the loading screen, so that first load takes a little longer: about 6 to 11 seconds
for 240 items in our tests. The screen waits 60 seconds at most, the next loads and the menus make the rest. What you
first see in a chest, on a body or in a shop comes in while the menu is up: first the flat sign, a moment later the
picture, the rows in sight first.
It takes about 20 KB on disk for each kind of item and a few hundred MB of memory in the game that makes them. The
files lie in Data/Textures/InventoryReforged/Items (Overwrite in Mod Organizer). After a new retexture or model of an
item remove that folder and the pictures are made again. Pictures in the list in the mod's menu switches them off, Height
of the rows, 100 to 200%, is on its Item list page and on the sheet of the sliders button, where the list follows at once.
- A broken model of an item crashes the game in its own reader, without this mod too when you point at its row. The mod
  notes what it's making, so after one crash that item keeps its flat sign (Skipped.txt beside the pictures, take its
  line out to try again) and the save loads on
- The loading screen draws nothing see-through, so glass comes out solid there and the glint of gems goes. Pictures made
  in a menu don't have this
- The first menu after a restart of the computer can be less smooth for about 2 seconds, the files are read from disk

What goes where
- SKSE/Plugins/InventoryReforged.dll   the plugin, it loads the panel into the item, magic and crafting menus
- SKSE/Plugins/InventoryReforged.ini   every switch with a comment
- SKSE/Plugins/InventoryReforged/      the answers of the installer that change the start (optional)
- Interface/InventoryReforged/panel.swf the panel itself. No file of SkyUI is replaced
- Interface/InventoryReforged/eyes.swf  the eyes of the slots, drawn over the 3D models in the slots
- Interface/Translations/InventoryReforged_<LANGUAGE>.txt   every word of the panel and the menus
- Textures/InventoryReforged/Items/     the pictures of the rows, made by the game as you play
- Scripts/InventoryReforged.pex          the script other mods call (see For mod authors), always installed
- Source/Scripts/InventoryReforged.psc  its source, to compile a mod against
- InventoryReforged.esp, Scripts, MCM   the menu (optional)

Compatibility
Everything checked, by kind of mod, is in compatibilities.md beside this readme.

Translate
Every word the panel and its menus show is in Interface/Translations/InventoryReforged_<LANGUAGE>.txt, one file for
each language of the game, all of them in English to begin with. Open the one of your game's language (sLanguage in
Skyrim.ini) and change the text after the tab on each line. Keep the part before the tab as it is. A # stands for a
number or a name the mod puts in, #1 and #2 may change places. Save the file as UTF-16 LE (Unicode in Notepad).
A translation can go out as a small mod of its own with just that file.

Bug reports
Releases has a debug build beside this one (InventoryReforged-1.7.0-debug). It writes every step of the mod into
InventoryReforged.log and costs frame time, use it only to make a bug report and go back to this build after. Its
readme says step by step what to send.

Source
The code is open, in the repository the archive comes from. The folder "source" holds a copy of the plugin and the panel, see its readme. The plugin links CommonLibSSE-NG
and is under the GNU GPL 3 like it. Nothing in that folder goes into the game.

Uninstall
Remove the files. Slots you hid on your character and your followers show again, followers pick their gear as the
game makes them, a save made with the mod loads fine without it.
