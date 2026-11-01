# Inventory Reforged for SkyUI

English | [Українська](README.uk.md)

Your character, your gear and everything you carry, at a glance and one click away.

This brings the inventory up to what modern RPGs have, without taking away anything SkyUI does. It's made for SkyUI as it comes, no skin needed: every picture on this page is plain SkyUI 6.11. UI skins on top of it work too (see [Compatibility](#compatibility)). The mod only touches how you work with your inventory: no extra load on FPS and no memory leaks. Personally tested on Skyrim Special Edition 1.7.104.0 in a load order of 230+ mods through 10+ hours of my own playthrough.

## Requirements

- Skyrim Special Edition or Anniversary Edition with SKSE64 and Address Library for SKSE Plugins
- SkyUI
- No DLC
- Built and tested on game versions 1.7.104 (SKSE64 2.3.1), 1.6.1170 (SKSE64 2.2.6) and 1.5.97 (SKSE64 2.0.20), with Address Library for SKSE Plugins 13 (All in One) and SkyUI 6.11

## Installation

Download the archive from [Releases](../../releases) and install it with Mod Organizer 2 or Vortex.

By hand: copy the content of the folder `core` of the archive into `Data`, for the menu the content of `menu` too.

## In short

1. The right side of the inventory gets an equipment panel: a model of your character, which you can turn with the mouse, and slots with everything it wears

![panel](pictures/01-panel.jpg)

2. Real pictures of your items in the rows in place of flat signs: in the inventory, a chest, on a body and in a shop. They're made from your own models and textures, so they show your items as they are, mod items too. The rows can be made taller and the pictures grow with them

![rows pictures](pictures/p51-rows-pictures.jpg)

3. Followers get the same panel. In a follower's trade ("Let's trade some things") you see them, everything they wear, their default outfit too, and their numbers. Drag a piece onto a slot, or right click it and Equip, and it goes on them, from their things or from yours. What you put on stays on and they fight with it: they don't swap it for "better" gear, in a fight or out of it, and the game doesn't put their old outfit back (Followers keep what you give in the mod's menu, on by default). The exception is a third-party mod that keeps changing a follower's gear on its own (I left that alone so as not to break quest lines or how a follower behaves). A follower's drained weapon can be recharged right in the trade, with their soul gems or yours, and their own potions and food they use themselves, from the row's menu

![follower](pictures/p37-follower.jpg)

![follower recharge](pictures/p48-follower-recharge.jpg)

4. Weapons get a fuller description (swing time, reach, DPS, DPM, stagger, crit damage), and so does armor (the share of a hit this piece and your whole set stop, how much longer you last with it). These lines can be switched off or resized in the mod's settings:

![weapon window](pictures/p03-weapon-window.jpg)

![armor window](pictures/p04-armor-window.jpg)

5. Any piece of your gear except weapons and shields can be hidden with the eye on its slot. It stays worn with all its bonuses, it just isn't seen on your character, in the menu or in the world. The same works on your followers:

![helmet hidden](pictures/p09-helmet-hidden.jpg)

6. Crafting stations get the panel too. At a forge, a workbench, a tanning rack, a grindstone or an enchanter your character and your slots stand beside the recipes, and the card of a recipe with its model comes up in the item window. A right click on a piece of armor or a weapon tries it on for show, on you or on a companion, without making anything. The weapons and armor of a station get their subcategories

![forge](pictures/p45-forge.jpg)

![forge tried](pictures/p46-forge-tried.jpg)

7. The magic menu gets the same panel: your character between the slots of your two hands and your voice

![magic](pictures/p42-magic.jpg)

![magic hands](pictures/p43-magic-hands.jpg)

8. Gear is compared with what you wear: a green arrow with +N next to the name when it's better, a red one with -N when it's worse. It's a rough comparison by the raw damage or armor number only. The item window weighs the rest, each number with a green or red one in brackets

![arrows](pictures/p05-arrows.jpg)

9. Quest items are marked right in the list, and the item window tells whether one is still needed and for which quest

![quest items](pictures/p32-quest-items.jpg)

10. Subcategories for weapons, apparel, potions, food, books and misc, one for junk in ALL, and the weapons and armor of crafting stations get their own. Sorting by the items added last (LAST ADDED) and by the weight of a whole stack (SUMW)

![weapons](pictures/p10-weapons.jpg)

![apparel](pictures/p11-apparel.jpg)

![potions](pictures/p12-potions.jpg)

![food](pictures/p13-food.jpg)

![books](pictures/p14-books.jpg)

![misc](pictures/p15-misc.jpg)

![forge subcategories](pictures/p50-forge-subcategories.jpg)

![sorting](pictures/16-sorting.jpg)

11. New items: everything you got since you last closed the inventory has a dot on its row's icon, and so does the subcategory it lies in

![new items](pictures/p49-new-items.jpg)

12. A full inspect view of any item in 3D, turned and zoomed: the item zoom key of the game (C), the lens in the item window or Inspect in a menu

![inspect](pictures/06-inspect.jpg)

13. A click on an empty slot filters the list down to what can go there

![slot filter](pictures/15-slot-filter.jpg)

14. A right click on a row opens a menu of what to do with the item: equip in the right or the left hand, use or read, drop one, all or some, add to favorites, mark as junk, details and inspect. In chests and shops the same lines take, store, buy and sell

![row menu](pictures/p19-row-menu.jpg)

15. Moving things is easier: the row's menu passes as many as you like, the X key moves the whole stack, and a right click on a subcategory in a chest takes or stores all of it. Stolen copies get a row of their own, so they never go along with yours by mistake

![chest subcategory](pictures/p33-chest-subcategory.jpg)

16. Junk: mark an item with a right click or the J key, and SELL ALL JUNK in a shop sells everything marked in one go, STORE ALL JUNK in a chest puts it there, after a list of what goes

![junk](pictures/p34-junk.jpg)

17. The character drawer: a tab at your character's feet pulls up the whole status and all the numbers of your character, it works with followers too

![drawer](pictures/p27-drawer.jpg)

18. Modular armor, a cloak with a bag and a scarf, rings on many fingers with MARA: a slot with several pieces pulls out a strip where each piece opens, hides and comes off on its own

![strips](pictures/p29-strips.jpg)

![jewelry](pictures/p31-jewelry.jpg)

19. The look of the panel is set right in the inventory, with the sliders button beside ALL ITEMS, and the gold and parchment of the mod can be changed in the menu when they don't sit with your UI

![look](pictures/p36-look.jpg)

![colours](pictures/p30-colours.jpg)

20. Gamepad: a click of the right stick moves the input to the panel and back, the d-pad walks the slots, Y opens the look sheet (see Gamepad below)

![gamepad](pictures/p35-gamepad.jpg)

## Important

- No file of SkyUI is replaced, the mod loads into its menus as they open. Your SkyUI version and the mods made for it stay as they are
- Every feature can be switched off in the menu of the mod: drawn by MCM Helper when you have it, by SkyUI itself when you don't, and with SKSE Menu Framework the same pages are in it too. The same switches are in an ini file too
- It can go into a game in progress and works at once. It can be taken out too: hidden pieces simply show again
- Know your Skyrim, a browser of everything your game knows, is a mod of its own, and with the panel it opens right inside it. I recommend having both

## Your character and the slots

Your character always stands straight and at the same size, whatever you were doing when you opened the menu and whatever its race or build.

![doll turned](pictures/p08-doll-turned.jpg)

Modular armor with pauldrons and belts, a cloak with a bag and a scarf, rings on several fingers: when a slot holds several pieces, a small tab shows beside it. A click on the tab pulls out a strip of small slots, one for each piece, and each does for its piece what a big slot does: the model, the window, the menu, the eye, a double click takes it off. The arrows and the wheel scroll a long strip.

Hiding: a hidden helmet shows the hair, a hidden closed helmet the whole head. The choice belongs to the slot, so a new helmet stays hidden too. Weapons and shields can't be hidden. SMP hair under a hidden helmet shows but stands still while "disable SMP hair when wig equipped" is on in Faster HDT-SMP (its default): to that mod a hidden helmet is still worn. Switch it off in Faster HDT-SMP's menu and the hair moves as on a bare head. Show everything again in the menu of the mod brings it all back at once.

![world hidden helmet](pictures/10-world-hidden-helmet.jpg)

The character drawer opens with a click on its tab, or drag the tab up as far as you like, and the wheel scrolls what doesn't fit. The drawer stays open until you close it yourself.

You can change the place and size of your character through the mod's settings right in the inventory, and switch off the character's model and particular slots in those same settings.

## Clicks on slots

A click on a slot opens its details window beside it, the main actions on a right click are Inspect, Take off and Hide.

![slot window](pictures/p02-slot-window.jpg)

Drag a row onto a slot or onto your character to put it on, the slots that take it glow gold. A double click on a slot takes the piece off.

![drag](pictures/p07-drag.jpg)

## The item window

The details window of an item in the list has 3 modes: on hover, on hover after a delay, or never (then the card stays where it stands without IR). Details in a row's menu opens the details window in any mode. The window's size can be changed (70 to 160%), and the name, the descriptions, the numbers and the small lines each have their own text size (80 to 200%).

**Swing time and damage a second come from the game's own attack animations, the weapon's speed and your attack speed, so animation mods change them.** Armor shows the share of a hit the piece and your whole set stop under the game's cap, effective health and armor per weight. The numbers in brackets compare with what you wear (a shorter swing is better), a bow with your bow, melee with your melee weapon, and **in a follower's trade with their gear**. A grey = by the name for an equal item can be switched on in the mod's menu (honestly I'm not sure this feature is worth keeping at all).

Under the name stands the kind of the item, in the corner what it's made from (has to be switched on at install or in the settings), each enchantment is written on a line of its own, and at the foot quiet lines: the quest that needs it, how many are stolen, the mod it comes from and how many copies you already have (followers' inventories aren't counted, not sure it's worth it).

If a description is too long, a scrollbar shows up.

In chests and shops the same numbers go right into SkyUI's card, in its own letters. A long description gets a scrollbar there too. I also took the liberty of growing the description box automatically, moving the item's model up to a certain limit.

![chest card](pictures/p39-chest-card.jpg)

Body slot numbers (switched on in the menu) tell which slots a piece takes, so the parts of modular armor are easy to tell apart (this is more for mod authors and debugging).

![slot numbers](pictures/p28-slot-numbers.jpg)

Inspect: drag to turn the item, the wheel zooms, a right click, Esc or Tab close it. If any of this doesn't work, the mod isn't behaving as intended, please report a bug.

## Quest items

The sign on a row is gold while the item is needed, paler while its quest hasn't begun, and grey once it's behind you. The mod also finds what the game doesn't mark: items a quest guards, makes or holds in its scripts, like the sapphire claw of Shroud Hearth Barrow. A quest without a name is named by the place where it happens.

## Pictures in the list

No more going by names or generic icons alone! Now every item (even from a mod) gets its own picture, drawn to the left of its name.

- By default only what you and your followers carry is baked, while a save loads, with a bar on the loading screen, so that first load takes a little longer: about 6 to 11 seconds for 240 items (it depends on your hardware)
- The screen waits 60 seconds at most (a hard limit), the next loads and the menus make the rest
- **An item is baked only once, when it first shows up, after that the picture is reused**
- What you first see in a chest, on a body or in a shop comes in right in the menu: first the flat sign, a moment later the picture, the rows in sight first (so the first time you wait a little for the pictures of each item, but that's exactly once per item in the whole game)
- As for the price, it's about 20 KB on disk for each kind of item and a few hundred MB of memory in the session that bakes them. After that the files are only read and FPS in the menu barely notices (at least on my hardware)
- The files lie in `Data/Textures/InventoryReforged/Items` (Overwrite in Mod Organizer). **If you later install a retexture or a replacement model, remove that folder and the pictures are baked again (they won't be baked again on their own)**
- Pictures in the list in the mod's menu or Item pictures on the look sheet switch the pictures off, the signs of SkyUI or your skin stay then
- **To make the pictures bigger use the Height of the rows setting**, 100 to 200%, on the Item list page of the mod's menu and on the look sheet, where the list changes at once

## Finding things

The subcategory strip works in the inventory, chests and shops. A second click on a word lets it go, and the two groups of apparel add up: for example you can combine Light and Head, then light helmets stay.

The filter of an empty slot switches the list to the right category and splits what fits into words of its own.

The dot of a new row goes when the pointer passes over it, the rest when the inventory closes.

## Moving items

![chest menu](pictures/p20-chest-menu.jpg)

The stack key (X, you can change it) moves the whole stack of the row under the pointer. In a chest, Store what this chest holds stores from a subcategory only what the chest already has, so an ore chest gets just ore. The weight column turns red on an item that won't fit any more and amber on a stack that won't fit whole.

## Junk

A mark belongs to the item as such, so every next tankard of the same kind is junk too. In a chest you can take junk as well. **Worn items, favorites and anything a quest needs never go as junk, even marked.**

## Followers

- The tabs over the character are switched on in the menu of the mod (Tabs to switch to followers) and show each follower near you (if you don't see a follower's button, most likely they aren't near you)
- Switched to a follower you can trade items with them directly, with no need to go through the dialogue every time
- The pieces of their default outfit stand in the slots though the game keeps them out of the list: they can be inspected, taken off or replaced. One taken off or replaced stays in their inventory as an ordinary item with its own row and goes back on like anything else

![follower outfit](pictures/p40-follower-outfit.jpg)

- Your choice holds outside the menu and in fights. Their combat AI fights with the weapon, shield or torch you gave them, casts no spell from that hand, and when their inventory changes or a save loads the game shouldn't put anything of its own over your choice. A mod that changes a piece on its own gets it back a moment later. One that keeps changing the same piece back wins that piece after three changes in ten minutes, the rest of your choice holds. Only what you changed on the panel holds this way. With Followers keep what you give switched off in the mod's menu, the game dresses followers its own way
- Recharge in the menu of a follower's drained weapon lists your soul gems and theirs, by the game's own rules. Recharge a weapon in the menu of a filled soul gem charges a weapon of the one whose inventory is open
- Use on their potion or food uses it on them

![follower hidden](pictures/p41-follower-hidden.jpg)

- It works for the followers of any mod that opens their inventory the game's way, and for anyone with a body like yours. Panel in a follower's trade in the menu of the mod switches it off

## The look of the panel

The settings sheet right in the inventory. Everything takes effect at once and is kept in the same settings as the menu of the mod.

## Gamepad

- A click of the right stick moves the input between the list and the panel, holding it opens the inspect view, on a row of the list its menu
- On the panel the d-pad walks the slots, the strips, the subcategories, the follower tabs and the drawer. A is a click, X hides a piece, Y opens the look sheet, B goes back. The right stick turns your character, in the inspect view the item itself
- On the look sheet the d-pad walks its lines, left and right change a value, A ticks a line or turns the page
- Pushed up or down, the right stick scrolls a long description that has no more room
- In chests and shops holding the stick on a row opens its menu, and its click stays the game's zoom
- LB, RB, the left stick click and Back stay SkyUI's. The moment you move the mouse the input goes back to the list
- Mouse only: subcategories in chests and shops

## Settings

![menu panel](pictures/p24-menu-panel.jpg)

![menu list](pictures/p25-menu-list.jpg)

![menu window](pictures/p26-menu-window.jpg)

Everything is also in `Data/SKSE/Plugins/InventoryReforged.ini` with a comment on every line, and what you set in the menu or on the look sheet is kept in `Data/MCM/Settings/InventoryReforged.ini` and wins over it.

## Compatibility

The list has grown so big that even I feel bad looking at it on the main page 😅. See [compatibilities.md](compatibilities.md): skins, mods of the item list, descriptions, crafting, loot, rings, followers, camera, animations and bodies.

In short, the mod adds to SkyUI's menus and replaces no file, so it works with any SkyUI that keeps the same item menus, and changes no record of the game. A mod that replaces SkyUI's inventory menu as a whole may not keep the parts the panel hooks into. If the panel doesn't show, that is the reason.

Skins checked with pictures and tall rows: plain SkyUI 6.11, Dear Diary, Untarnished UI, Norden UI, Dragonborn UI, Edge UI, Nordic UI, SkyUI AIO Survival, Vel'dun UI. Skins on the old SkyUI 5.2 on game 1.6.1130 and later need Widescreen Scale Removed, as they ask themselves.

## Under the hood

- A picture is the item's model drawn by the game's own menu pass into an unseen patch of the frame, scaled down and written to a file. While a save loads the mod waits on its own signal, the loading screen draws on its thread and bakes one picture each frame
- Your character is a copy of your own 3D, made when the menu opens and again when your gear changes, in the same little 3D scene the game uses for the preview of a selected item. The copy is put into a calm standing pose taken from the game's own idle, one for men and one for women. Its size comes from the length of its bones, which does not change with the pose, so every body fills the panel the same
- The game draws the menu first and its 3D scene over it. The mod draws your character before the menu, with the game's own drawing call, so windows and menus lie over it like over the world
- A slot of armor is another copy of you in which everything but that piece is switched off. That is why boots stand and a cloak hangs
- Hiding works where the game puts your worn gear onto your body: for a hidden slot the piece is skipped, while for the game it stays worn. The game switches your head and the covered part of your hair off by what you wear, even when the helmet is skipped, so the plugin switches them back on. For the slot of a hidden piece the plugin puts the piece on a copy of your body itself, tied to its bones and in its own textures the way the game does it
- Outside the menu the mod does nothing while no slot is hidden. With a slot hidden it looks at the head of your character each frame, 0.005 ms in the test. In the menu its own work takes about 0.25 ms a frame, and a copy is made only when what you wear changes

## Good to know

- The loading screen draws nothing see-through, so glass comes out solid there and the glint of gems goes. Pictures baked in a menu don't have this
- A broken model of an item is one the game itself can't read: without this mod too it crashes when you point at such a row. So that such an item can't lock a save out, the mod notes what it's baking. After one crash that item keeps its flat sign, its file goes into `Skipped.txt` beside the pictures and the save loads on
- On Edge UI above 100% row height the line between its rows runs through the text
- The first menu after a restart of the computer can be less smooth for about 2 seconds, the picture files are read from disk
- Slot models and the model in the item window are drawn over the menu. A slot model steps out while a window lies over it, so the mod opens windows beside the slots. The right-click menus are drawn once more over the 3D, so they lie on the models
- The armor numbers follow the armor rating rule of the game (a share of damage per point, up to a cap) with the settings of your game. Mods that compute armor in a script of their own are not counted
- Combat mods that zero weapon stagger (Blade and Blunt with its own stagger bar) make the Stagger line read 0 on every weapon
- A second copy of the piece in a hidden slot (the same helmet, tempered or enchanted) swaps in from the inventory. Put on from favorites or a hotkey, the game ignores it while the slot is hidden
- Animated models (like Animated ElSopa Potions Redone) stand still in the window and the inspect view, the same as in the game's own preview
- MCM Helper may keep a value in memory and show the old one after a change on the look sheet. The new one is the one that works, and SkyUI's menu and SKSE Menu Framework read the values live
- An inventory or magic menu that opens at once but shows its list only after about 3 seconds is SkyUI waiting for its own settings script. SkyUI builds the list once its Papyrus script (`SKI_SettingsManager`) answers and gives up waiting after 3 seconds, and a busy Papyrus answers late, most often in the first minutes of a game while many mods run their first setup. It happens without this mod too. Players found that `bIgnoreMemoryLimit = true` in the [Experimental] section of Papyrus Tweaks NG's ini makes it go
- `InventoryReforged.log` in `Documents/My Games/Skyrim Special Edition/SKSE` goes with every bug report (see How to report a bug). Each time an item menu closes and on every save the plugin writes there how long its work took and what it still holds, so a slowdown or a leak shows up in it

## How to report a bug

Releases has a debug build beside the normal archive (InventoryReforged-x.x.x-debug). It writes every step of the mod into its log and costs frame time, so it is only for bug reports.

1. In your mod manager switch the normal Inventory Reforged off and the debug build on, in the same place of the load order. **Only one of them may be active**
2. Start the game and try to reproduce the bug
3. Close the game. From `Documents/My Games/Skyrim Special Edition/SKSE` take `InventoryReforged.log`, and the newest crash log of Crash Logger or Trainwreck if the game crashed
4. A freeze (the game stops but does not close): while it's frozen press Ctrl+Shift+Esc, open the Details tab of the Task Manager, right click SkyrimSE.exe and choose Create memory dump file. Zip the .DMP and upload it to Google Drive, Mega or similar
5. If you can, write what you did, what you expected and what happened instead, a screenshot if it's something you see, and links to the files. Put the log on pastebin.com or a file host and post the link, not the whole text
6. Switch the debug build off and the normal build on again

## Translations

Every word of the panel and of its menus (MCM Helper, SkyUI's Mod Configuration and SKSE Menu Framework) comes from `Data/Interface/Translations/InventoryReforged_<LANGUAGE>.txt`. Words SkyUI already has, like the names of subcategories and kinds (Heavy, Head, Ring), come from SkyUI's own translation of your language, the file has them only for when SkyUI doesn't. The mod ships one for each language of the game, all in English to begin with. To translate, open the file of your game's language, change the text after the tab on each line and keep the part before it. A # stands for a number or a name the mod puts in, #1 and #2 may swap places. Save it as UTF-16 LE (Unicode in Notepad). Translations are welcome as mods of their own, just that one file.

## For mod authors

Follower frameworks and companion mods get the panel with no code: open the inventory with `Actor.OpenInventory(true)`. A small Papyrus API (script InventoryReforged) tells a mod what the player put on or took off a follower and keeps the panel's hands off an actor while a mod needs that. Everything about it, with an example, is in [InventoryReforged API.txt](scripts/interface/equipment/api/InventoryReforged%20API.txt).

## The code

An SKSE plugin in C++ plus an ActionScript 2 movie the plugin loads into SkyUI's menus.

| Folder                                | What it is                                                             |
| ------------------------------------- | ---------------------------------------------------------------------- |
| `plugins/equipment-panel`             | The SKSE plugin, `source/Debug` builds only into the debug edition     |
| `plugins/shared/source`               | C++ shared with my other mods                                          |
| `plugins/cmake/ports`                 | The vcpkg port of CommonLibSSE-NG                                      |
| `scripts/interface/equipment/source`  | The panel, `build.py` joins the parts in the order of its `PARTS` list |
| `scripts/interface/equipment/overlay` | The small movie drawn over the 3D of the item menus                    |
| `scripts/interface/equipment/menu`    | The mod's menu pages and Papyrus scripts                               |
| `scripts/interface/equipment/api`     | The API for other mods                                                 |
| `scripts/interface/equipment/tests`   | Tests of the panel, run in node                                        |

### Build

The plugin needs Visual Studio with the C++ tools, its CMake, Ninja and vcpkg. The first run builds CommonLibSSE-NG and takes several minutes:

```
plugins\build.ps1 equipment-panel
```

The whole package also needs:

- Python 3.11 or newer with Pillow
- Java and [JPEXS Free Flash Decompiler](https://github.com/jindrapetrik/jpexs-decompiler) at `tools/ffdec/app/ffdec.jar`
- [Caprica](https://github.com/Orvid/Caprica) at `tools/caprica/app/Caprica.exe`
- the Papyrus sources of the game, SKSE and the SkyUI SDK, and `TESV_Papyrus_Flags.flg` from the Creation Kit

`IR_TOOLS` points at the tools if they live somewhere else.

```
set PAPYRUS_IMPORTS=C:\path\to\skse\Scripts\Source;C:\path\to\game\Scripts\Source;C:\path\to\skyui-sdk
set PAPYRUS_FLAGS=C:\path\to\TESV_Papyrus_Flags.flg
cd scripts
python -m interface.equipment.build
python -m interface.equipment.release --no-archive
```

The results land in `out/skyui-equipment`.

### Tests

```
node scripts/interface/equipment/tests/logic.test.cjs
node scripts/interface/equipment/tests/debug.test.cjs
```

`PANEL_CALLS=1` runs the logic tests the way the debug build wraps them.

Functions marked `for tests` stay in the release movie on purpose: an automated run of the real game drives them. That setup isn't part of this repository.

### Words the code uses

- **doll** - the 3D copy of the character shown in a menu
- **card** - SkyUI's item card, **window** - the mod's bigger window of item details
- **strip** - the small row of pieces that opens beside a slot
- **chip** - a small filter button over the list
- **lens** - the magnifier over a slot
- **look sheet** - the settings page inside the inventory
- **told** - a value from a script or a mod that wasn't checked yet

## Licence

GNU General Public License 3, see [LICENSE](LICENSE). The plugin links CommonLibSSE-NG, so its modding and linking exceptions apply too. [licences](licences/README.txt) lists everything the mod is built with. The mod's archive holds a copy of the code in the folder `source`, the installer never copies it into your game.

## Credits

SkyUI by the SkyUI team, the base this mod lives on. moreHUD Inventory Edition by Ahzaab, which the item window keeps working with. Built with CommonLibSSE-NG.

**Shout-outs**

Special thanks to xLenax, euTHEgusta and ApocryphaRealm for helping track down the freezes caused by compatibility issues with KIT and similar mods!
