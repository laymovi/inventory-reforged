# Compatibility

The plugin loads a script of its own into SkyUI's inventory, container, barter, magic and crafting menus as they open. No file of SkyUI or of another mod is replaced and no record of the game is changed, the light plugin only holds the menu. So the mod works with any SkyUI that keeps the same item menus, and with mods that change other parts of SkyUI. A mod that replaces SkyUI's inventory menu as a whole (its inventorymenu.swf) may or may not keep the classes the panel hooks into. If the panel doesn't show, that is the reason. Below is what was checked, by kind of mod. A version named is the one that ran in the game with the mod.

## UI skins

- SkyUI 6.11 as it comes: every picture of the readme is plain SkyUI
- Checked on 1.7.0 with pictures in the rows at 100% and 150% row height, in the inventory, a chest and a shop: Norden UI, Edge UI, Nordic UI, Dear Diary, Dragonborn UI, Untarnished UI, Vel'dun UI and SkyUI AIO Survival. On Edge UI above 100% the line between its rows runs through the text
- Checked on 1.6.0 in the inventory, a chest and a shop, with long item descriptions: Dear Diary 3.0.6, Untarnished UI 1.1.6 on Dear Diary Dark Mode 1.1.1, Norden UI 1.2.6, Dragonborn UI 0.80, Edge UI 0.61, Nordic UI 2.4.1, SkyUI AIO Survival 7.4 and Vel'dun UI 1.0.7. Subcategories sit under the category bar of each skin and filter the same items as in plain SkyUI
- Paper skins (Dear Diary and the like): the panel writes in dark ink, its windows become paper sheets, the item window keeps to the page of the list
- Skins on the old SkyUI 5.2 (Dear Diary, Vel'dun UI) on game 1.6.1130 and later need Widescreen Scale Removed, as the skins themselves ask: without it the game squeezes their menus to half their width. The panel keeps its own proportions either way
- Edge UI shows your carry weight and gold at the corners of its item preview area, which is where your character stands now. With Dragonborn UI and Vel'dun UI the last row of the list stays clear of the weight and gold at the bottom
- The magic menu: checked with plain SkyUI 6.11, Norden UI 1.2.6, Dear Diary 3.0.6 and SkyUI AIO Survival 7.4, the panel, the slots and the card of a spell sit right in each. A skin that builds its magic menu without SkyUI's list keeps it as it is
- Crafting stations: the crafting menus of plain SkyUI, Norden UI, Edge UI, Dear Diary, Untarnished UI and Vel'dun UI

## Item list mods: icons, categories, columns

- Inventory Interface Information Injector (I4) 1.1.1, I4 Improved 0.4.0 and Dynamic Inventory Icon Injector: rows keep their icons, and a slot without a model shows the row's icon in the row's colour. With I4 Improved a subcategory or slot filter changes the list at once
- Object Categorization Framework 6.1.0 and Keyword Item Distributor: subcategories pick the items their keywords sort, with Edge UI and Dragonborn UI too
- Kome's Inventory Tweaks 1.21 (with I4, KID and OCF) and other mods that bring SkyUI settings of their own: the inventory opens with their icons and columns, the whole stack weight goes into their weight column. A column such a file leaves without sort states is passed over
- Aura's Inventory Tweaks 4.5 (with Edge UI, BOOBIES and The Handy Icon Collection): Last added and stack weight sorting go into its own name and weight columns
- Smooth Scrolling for Many SkyUI 1.3.1 and other mods that make the list glide, checked with its SkyUI 6 option: rows dragged onto slots, the menu of a row and the item window follow the gliding list
- moreHUD Inventory Edition: its icons stay on the item card
- Completionist 5.0.0.4 (from a player's report): the colour tag it adds to a name stays whole when the panel shortens a row's name, and the slots and the inspect view show the name without it
- PNG Icon Injector 1.0.0 (from a player's report): its item and status icons stay, the compare arrow, quest sign and junk sign go after its status icons. The same holds for any mod that puts icons of its own after the name

## Item descriptions and tooltips

- Description Framework 3.0.0 with Vanilla Item Descriptions 1.1 and Weapons, Armors, Soul Gems, Scrolls and Food and Drink Have Description: the description goes into the card, the item window grows under it and its numbers stand under the text, on vanilla and mod items alike
- Ingredients Have Description 1.6: its text stays clear of the item window's numbers
- Long descriptions and enchantments keep their letter size on all the skins above. Where there's no more room they keep whole lines and scroll: by the wheel over them, by the right stick of a gamepad, or by themselves after a pause
- LoreBox 1.0.8: its tooltips stand over the item window's model

## Crafting

- Crafting Categories 1.2.0, Complete Crafting Overhaul Remastered 2.6.4 and WACCF 2.11.4, all three together at a forge: the panel, the recipe's card in the item window, trying on for show and the subcategories of weapons and armor

## Rings, amulets and pieces of their own

- Mods that make rings and amulets slotless (MARA and the like): a piece with no body slot at all goes to the ring or neck slot by its ring or necklace keyword, so all of them show in those strips and come off with a double click. In the list they get the ring and necklace icons of your SkyUI icon theme and the kind Ring or Amulet, in place of the plain shield SkyUI draws for a piece without a slot. MARA draws them itself, as copies of their models on your fingers and neck, and the eyes hide those copies too: the whole slot, or one piece from its strip. Two pieces that look exactly alike hide together. Checked with MARA 0.0.6, which itself does not start on game 1.7.104 yet. For MARA with Community Shaders: CS 1.9.1 switches itself off when it finds a file named MARA.dll, and then True PBR textures turn white
- My Precious...es - Multiple Rings SKSE 1.0.2, checked on 1.7.0 with pictures in the rows at 140%, through a save and a load on game 1.7.104: every ring on every finger shows in the strip of the ring slot. A ring on its left hand finger comes off with a double click like any piece. Rings on its other fingers come off in its own finger menu, and they can't be hidden from here, that mod draws them itself
- Modular armor with pauldrons, belts, bags and scarves in body slots of their own: a slot holding several pieces opens a strip of them, each with its own model, window, menu and eye

## Followers

- Follower frameworks and companion mods: the panel comes to any trade opened with Actor.OpenInventory(true), with no code of theirs. See [InventoryReforged API.txt](scripts/interface/equipment/api/InventoryReforged%20API.txt)
- Follower Equip Control 2.1.0, checked on game 1.6.1170: it shows a follower's outfit among the rows of their trade, and those pieces count once on the doll and in the numbers. A right click with Ctrl, Shift or Alt held is left to SkyUI and to mods like it (its Ctrl + right click puts a piece in the follower's left hand), a plain right click opens the panel's menu of a row. On game 1.7.104 Follower Equip Control itself does not start yet, it stops the game at the start with "failed to open address library file". It hooks the item card of chests and trades again over any mod that hooks the card after it, and takes that mod's hook for its own original. A mod that hooks the card the usual way then goes round in a circle with it until the game drops the call, and the card stays empty ("undefined", DAMAGE 000). This mod copes with it from 1.6.2, before that its cards in chests and follower trades came out so with FEC
- Mods that dress a follower on a timer of their own: what you put on through the panel goes back on a moment later. A mod that keeps changing the same piece back wins that piece after three changes in ten minutes, the rest of the choice holds. InventoryReforged.log names the piece and the follower ("another mod changes ... back each time"). The card of a follower's piece names the mod that last took it off or put it on them ("! Taken off Lydia by SomeMod.esp"): a script by the plugin its script belongs to, an SKSE plugin by its DLL. A mod that attaches its script to a form of the game itself, or works through another plugin's Papyrus functions, shows as that form's owner (no line) or as that plugin's DLL. To let the game and such mods dress followers their own way, switch off "Followers keep what you give" on the Panel page of the menu
- Follower Equip Control and other mods that steer a follower's combat AI: both score the AI's choices, this mod's answer goes over theirs only for the hands and slots you chose a piece for through the panel. Follower Equip Control also keeps a follower's weapons in their hands itself: in a test (game 1.5.97, FEC 2.1.0) a sword put in Lydia's right hand through the panel went back to her own, the armor held. With FEC, weapons go on through its Mod Key

## Camera, the player in menus, animations

- Skyrim Souls RE 3.2.0: it keeps the world running under the menus and turns the camera when the pointer touches an edge of the screen. While the inventory is open the mod keeps the camera still, so the world behind the panel stays put. To let Souls RE turn it there as in its other menus, switch off "Keep the camera still" on the Panel page of the menu. A follower stands still while their trade is up, as in a trade from a talk, so Souls RE doesn't close it when they would walk off
- Menu Studio 1.2.0, Show Player In Menus and mods that show the real player in menus: the panel's character steps aside for them
- Apparel Preview 1.2.0: the zoom key opens the inspect view, and what you try on shows on your character in the panel
- A camera you turned to your own face yourself, say to watch an idle of EVG Conditional Idles 1.51 or with True Directional Movement: the panel's character stays
- Fitting Room - ESO Style Transmog 1.2.0 with FLICK NG 1.7.0, checked on game 1.7.104: its editor opens over the inventory with its key and closes back to the panel. While the editor is up, the panel's character and slot models step out and leave its screen alone. The Outfits hint it adds to the bottom bar goes as soon as SkyUI draws the bar again, the same without this mod
- Immersive Equipping Animations and the like: your character in the panel plays their equipping animations
- Immersive Equipment Displays: gear it hides on the body (a shield on the back while it's in hand) stays hidden on the panel's character
- Combat Gameplay Overhaul 1.1.0 and other grip mods: a two-handed weapon held in one hand goes to the left hand through the row menu and the slot, and both hands show it. A follower's left hand still takes no two-handed weapon. The panel goes by the weapon's equip slot, so a mod that changes it this way needs no patch

## Loot

- QuickLoot IE 4.1.3 and QuickLoot Redesigned 1.1: the loot window stays theirs, and the chest's own menu, their Search too, has the mod's card, row menus and junk

## Bodies, hair, looks

- CBBE, CBBE 3BA and The New Gentleman: a hidden body piece shows what taking it off shows. The New Gentleman's own cover piece stays out of the slots
- Body physics (CBPC, SMP) under a hidden piece moves as without that piece (UBE 2.0 with 3BA, CBPC 1.7.2, Faster HDT-SMP 4.1.1 in a test: breasts, butt and The New Gentleman's bones swing as on the naked body)
- RaceMenu hairstyles from packs like Dint999 HairPack02, and wig mods: the hair stays under a hidden helmet
- SMP hair under a hidden helmet shows but stands still while Faster HDT-SMP's "disable SMP hair when wig equipped" is on (its default): that rule looks at what is worn in the inventory, and a hidden helmet is still worn. Switch it off in Faster HDT-SMP's menu (or "disableSMPHairWhenWigEquipped": false in its configs) and the hair moves under a hidden helmet as on a bare head. Hair under a helmet you see is then simulated too, unseen
- Items that share one model with different textures (Cards Items and mods like it, the monk robes of the game itself): the slots, the window and the inspect view dress them in the textures the item gives, as in the world
- Armor with SMP physics: it fills its slot and the inspect view
- Animated models (Animated ElSopa Potions Redone 1.0.2): they stand still in the window and the inspect view, the same as in the game's own preview
- Community Shaders: hair keeps its colour with its hair shadow, and slot models and the item preview stay steady with TAA

## Quest items

- Mods that keep items in the scripts of a background quest (Honed Metal 1.27): those items aren't marked as quest items

## The mod's menu

- MCM Helper, SkyUI's own Mod Configuration and SKSE Menu Framework 3.14: the same pages in each, with the same values

## Know your Skyrim

- The browser opens in the panel, in place of your character and the slots, and the panel's windows, menus and look button keep their places around it. Each of the two works on its own too. On a gamepad the browser's page takes the right stick while the browser has the input, a long description of the card waits then

## Gamepad

- In chests and shops a click of the right stick stays the game's zoom of the item, a hold opens the menu of the row

Also tested alongside Precision and moreHUD, and in my own load order of 230+ mods on game 1.7.104.
