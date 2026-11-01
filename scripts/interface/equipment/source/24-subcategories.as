Equipment.STRIP_HIGH = 30;
Equipment.CHIP_TEXT = 15;
Equipment.CHIP_ICON = 19;
Equipment.ICON_TO_WORD = 5;
Equipment.CHIP_GAP = 18;
Equipment.CHIP_DIM = 45;
Equipment.CHIP_LIT = 80;
Equipment.CHIP_EMPTY = 18;
Equipment.UNDERLINE_BELOW = 3;
Equipment.SEPARATOR = 0.36;
Equipment.GROUP_SEPARATOR = 0.6;

// Subcategories sit in a strip of their own under the category icons, written like the column names of
// SkyUI. A group of them is one choice, groups add up: Heavy and Head together leave heavy helmets.
// One pressed again lets its group go. A chip that's alone is a kind the other groups don't split, a shield has no
// head or feet, so it lets the other groups go and a press in them lets it go
Equipment.CHIP_ROWS = {
   weapons:[
      [
         {key:"oneHanded", words:"$One-Handed", fallback:"One-Handed", icon:"sword"},
         {key:"twoHanded", words:"$Two-Handed", fallback:"Two-Handed", icon:"battleaxe"},
         {key:"ranged", words:"$Bows", fallback:"Bows", icon:"bow"},
         {key:"staff", words:"$Staves", fallback:"Staves", icon:"staff"},
         {key:"ammo", words:"$Ammo", fallback:"Ammo", icon:"arrows"}
      ]
   ],
   armor:[
      [
         {key:"light", words:"$Light", fallback:"Light", icon:"jerkin"},
         {key:"heavy", words:"$Heavy", fallback:"Heavy", icon:"plate"},
         {key:"clothing", words:"$Clothing", fallback:"Clothing", icon:"robe"},
         {key:"jewelry", words:"$Jewelry", fallback:"Jewelry", icon:"ring"},
         {key:"shield", words:"$Shield", fallback:"Shields", icon:"shield", alone:true}
      ],
      [
         {key:"head", words:"$Head", fallback:"Head", icon:"helmet"},
         {key:"body", words:"$Body", fallback:"Body", icon:"cuirass"},
         {key:"hands", words:"$Hands", fallback:"Hands", icon:"gauntlets"},
         {key:"feet", words:"$Feet", fallback:"Feet", icon:"boots"},
         {key:"other", words:"$Other", fallback:"Other", icon:"cloak"}
      ]
   ],
   // potions get the colours of the bars they fill
   potions:[
      [
         {key:"health", words:"$Health", fallback:"Health", icon:"potion", tint:0xD4483C},
         {key:"magicka", words:"$Magicka", fallback:"Magicka", icon:"potion", tint:0x4F8BE6},
         {key:"stamina", words:"$Stamina", fallback:"Stamina", icon:"potion", tint:0x62BE52},
         {key:"poison", words:"$Poisons", fallback:"Poisons", icon:"poison", tint:0xA864D2},
         {key:"otherPotion", words:"$Other", fallback:"Other", icon:"potion", tint:0xE2B456}
      ]
   ],
   food:[
      [
         {key:"meal", words:"$Food", fallback:"Food", icon:"food"},
         {key:"drink", words:"$Drinks", fallback:"Drinks", icon:"mug"}
      ]
   ],
   books:[
      [
         {key:"book", words:"$Books", fallback:"Books", icon:"book"},
         {key:"note", words:"$Notes", fallback:"Notes", icon:"note"},
         {key:"map", words:"$Maps", fallback:"Maps", icon:"map"},
         {key:"spellTome", words:"$Spell Tomes", fallback:"Spell Tomes", icon:"tome"}
      ]
   ],
   // ALL has one, the rows marked as junk, while the junk of the mod is on
   all:[
      [
         {key:"junk", words:"$Junk", fallback:"Junk", icon:"junk"}
      ]
   ],
   misc:[
      [
         {key:"ore", words:"$Ore", fallback:"Ore", icon:"ore"},
         {key:"ingot", words:"$Ingots", fallback:"Ingots", icon:"ingot"},
         {key:"gem", words:"$Gems", fallback:"Gems", icon:"gem"},
         {key:"soulGem", words:"$Soul Gems", fallback:"Soul Gems", icon:"soulgem"},
         {key:"pelt", words:"$Pelts", fallback:"Pelts", icon:"pelt"},
         {key:"otherMisc", words:"$Other", fallback:"Other", icon:"sack"}
      ]
   ]
};

// what SkyUI calls the kinds of potions, food, books and things it knows (skyui.defines.Item)
Equipment.HEALTH_POTIONS = [0, 1, 2];
Equipment.MAGICKA_POTIONS = [3, 4, 5];
Equipment.STAMINA_POTIONS = [6, 7, 8];
Equipment.DRINK = 13;
Equipment.MEAL = 14;
Equipment.POISON_POTION = 15;
Equipment.SPELL_TOME = 0;
Equipment.NOTES = [1, 2];
Equipment.MAP_BOOK = 3;
Equipment.MISC = 32;
Equipment.SOUL_GEM = 52;
Equipment.MISC_GEM = 0;
Equipment.MISC_INGOT = 7;
Equipment.MISC_ORE = 31;
Equipment.MISC_PELTS = [3, 4, 5, 23];

// SkyUI 5.2 knows ore and treasure maps by these forms of the game. Menu files built on an older SkyUI
// (Nordic UI, Edge UI) call ore an ingot and a map a note, so the chips look at the forms themselves
Equipment.ORE_FORMS = [371931, 371932, 371933, 371934, 371935, 371936, 371937, 371938, 373471, 466163, 67285099, 67204937, 67212713];
Equipment.MAP_FORMS = [909051, 979066, 996301, 996302, 996303, 996304, 996305, 996306, 996307, 996308, 996309, 996320];

// the kinds of potions, books and things that have a word of their own, so the rest is Other
Equipment.KIND_KEYS = {
   potions:["health", "magicka", "stamina", "poison"],
   misc:["ore", "ingot", "gem", "soulGem", "pelt"],
   books:["note", "map", "spellTome"]
};

// The mod's own file first when it has the words in another language, someone translated the mod. SkyUI's words
// after it, so the chips speak the language of the game with no translation of the mod. Any mod can put "$Bows" in
// English into the game's words, a player's own translation stayed English under it
Equipment.translated = function(chip)
{
   var own = Equipment.say(chip.fallback);
   if(own != chip.fallback)
   {
      return own;
   }
   var words = skyui.util.Translator.translate(chip.words);
   return words == undefined || words == "" || words.charAt(0) == "$" ? own : words;
};

// The groups of chips a family has. A crafting station's page can mix weapons and armor (Crafting Categories keeps its
// materials so), it gets a choice of the two first and the chips of the one chosen after it (39-crafting.as)
Equipment.chipRowsOf = function(family)
{
   if(family == "all" && (Equipment.settings == undefined || Equipment.settings.junk != true))
   {
      return undefined;
   }
   return Equipment.CHIP_ROWS[family];
};

// The category whose rows the list shows. Crafting Categories' tree lets its selection go as the pointer leaves it
// while its page stays, read as no category its chips went away. The lists keep the place of the page shown
Equipment.categoryEntry = function()
{
   var lists = Equipment.menu.inventoryLists;
   var list = lists.categoryList;
   var shown = lists._currCategoryIndex;
   return shown >= 0 && list.entryList != undefined && list.entryList[shown] != undefined ? list.entryList[shown] : list.selectedEntry;
};

// the plugin keeps the chips under this name, a crafting station keeps its own
Equipment.CHIPS_MEMORY = "chips";

Equipment.chipHolds = function(key, entry)
{
   var weapon = entry.formType == Equipment.WEAPON;
   var armor = entry.formType == Equipment.ARMOR;
   var slot;
   switch(key)
   {
      case "junk":
         return entry.equipmentJunk == true;
      case "weaponsKind":
         return weapon || entry.formType == Equipment.AMMO;
      case "armorKind":
         return armor;
      case "oneHanded":
         return weapon && Equipment.oneHanded(entry) && entry.subType != Equipment.STAFF;
      case "twoHanded":
         return Equipment.twoHanded(entry);
      case "ranged":
         return Equipment.ranged(entry);
      case "staff":
         return weapon && entry.subType == Equipment.STAFF;
      case "ammo":
         return entry.formType == Equipment.AMMO;
      case "light":
         return armor && entry.weightClass == 0 && !Equipment.isShield(entry);
      case "heavy":
         return armor && entry.weightClass == 1 && !Equipment.isShield(entry);
      case "clothing":
         return armor && (entry.weightClass == 3 || Equipment.unclassed(entry) && !Equipment.jewelryParts(entry));
      case "jewelry":
         return armor && (entry.weightClass == 4 || Equipment.unclassed(entry) && Equipment.jewelryParts(entry));
      case "shield":
         return Equipment.isShield(entry);
   }
   // Other of Misc takes whatever lands in Misc with no word of its own, torches are lights there
   if(entry.formType == Equipment.POTION || entry.formType == Equipment.BOOK || entry.formType == Equipment.MISC || entry.formType == Equipment.SOUL_GEM || key == "otherMisc")
   {
      return Equipment.kindHolds(key, entry);
   }
   if(!armor || Equipment.isShield(entry))
   {
      return false;
   }
   slot = Equipment.armorSlot(entry).name;
   if(key == "other")
   {
      return slot == "other" || slot == "amulet" || slot == "ring";
   }
   return slot == key;
};

Equipment.kindHolds = function(key, entry)
{
   var potion = entry.formType == Equipment.POTION;
   var book = entry.formType == Equipment.BOOK;
   var misc = entry.formType == Equipment.MISC;
   var i = 0;
   switch(key)
   {
      case "health":
         return potion && Equipment.has(Equipment.HEALTH_POTIONS, entry.subType);
      case "magicka":
         return potion && Equipment.has(Equipment.MAGICKA_POTIONS, entry.subType);
      case "stamina":
         return potion && Equipment.has(Equipment.STAMINA_POTIONS, entry.subType);
      case "poison":
         return potion && entry.subType == Equipment.POISON_POTION;
      case "meal":
         return potion && entry.subType == Equipment.MEAL;
      case "drink":
         return potion && entry.subType == Equipment.DRINK;
      case "note":
         return book && Equipment.has(Equipment.NOTES, entry.subType) && !Equipment.has(Equipment.MAP_FORMS, entry.formId);
      case "map":
         return book && (entry.subType == Equipment.MAP_BOOK || Equipment.has(Equipment.MAP_FORMS, entry.formId));
      case "spellTome":
         return book && entry.subType == Equipment.SPELL_TOME;
      case "ore":
         return misc && (entry.subType == Equipment.MISC_ORE || Equipment.has(Equipment.ORE_FORMS, entry.formId));
      case "ingot":
         return misc && entry.subType == Equipment.MISC_INGOT && !Equipment.has(Equipment.ORE_FORMS, entry.formId);
      case "gem":
         return misc && entry.subType == Equipment.MISC_GEM;
      case "soulGem":
         return entry.formType == Equipment.SOUL_GEM;
      case "pelt":
         return misc && Equipment.has(Equipment.MISC_PELTS, entry.subType);
   }
   // the Other of a family is what none of its named kinds holds
   var named = key == "otherPotion" ? Equipment.KIND_KEYS.potions : (key == "otherMisc" ? Equipment.KIND_KEYS.misc : (key == "book" ? Equipment.KIND_KEYS.books : undefined));
   if(named == undefined || key == "otherPotion" && !potion || key == "book" && !book)
   {
      return false;
   }
   while(i < named.length)
   {
      if(Equipment.kindHolds(named[i], entry))
      {
         return false;
      }
      i++;
   }
   return true;
};

// SkyUI names clothing and jewelry by keywords of the game, a mod's piece without them has no class at all
Equipment.unclassed = function(entry)
{
   return entry.weightClass != 0 && entry.weightClass != 1 && entry.weightClass != 3 && entry.weightClass != 4 && !Equipment.isShield(entry);
};

// a piece that sits only where jewelry sits: neck, finger, circlet
Equipment.jewelryParts = function(entry)
{
   return entry.partMask != undefined && entry.partMask != 0 && (entry.partMask & ~Equipment.JEWELRY_PARTS) == 0;
};
Equipment.JEWELRY_PARTS = 0x20 | 0x40 | 0x1000;

// which set of chips a category flag has, nothing for the categories without them. The flags of the other
// side of a container or a shop are the inventory ones moved up by ten bits
Equipment.FAMILIES = {f2:"weapons", f4:"armor", f8:"potions", f32:"food", f128:"books", f512:"misc", f1023:"all"};
Equipment.chipFamily = function(flag)
{
   var own = flag >= 1024 ? flag >> 10 : flag;
   return Equipment.FAMILIES["f" + own];
};

// Under the filter of a slot the subcategories chosen there are its own. The ones chosen before wait
// aside and come back when the filter goes
Equipment.chosenNow = function()
{
   return Equipment.activeSlot != undefined ? Equipment.slotChips : Equipment.chosenChips;
};

Equipment.chipFilter = {};
Equipment.chipFilter.applyFilter = function(entries)
{
   var chosen = Equipment.chosenNow();
   var kept = 0;
   var i = 0;
   var keep;
   var r;
   if(chosen == undefined || chosen.length == 0)
   {
      return undefined;
   }
   // the rows kept close up in one pass, as in the slot's filter
   while(i < entries.length)
   {
      keep = true;
      r = 0;
      while(r < chosen.length && keep)
      {
         keep = chosen[r] == undefined || Equipment.chipHolds(chosen[r], entries[i]);
         r++;
      }
      if(keep)
      {
         entries[kept++] = entries[i];
      }
      i++;
   }
   entries.length = kept;
};

// The subcategories shown when a menu closes come back with their category the next time a menu opens on it, the way
// the game keeps the category. The script is loaded anew with every menu, the plugin keeps the family and its chips.
// A category picked inside a menu starts clean: chips that came back on every switch looked stuck
Equipment.keepChips = function()
{
   var plugin = Equipment.plugin();
   var keys = [Equipment.chipsFamily];
   var r = 0;
   if(plugin == undefined || plugin.Remember == undefined || Equipment.chipsFamily == undefined || Equipment.activeSlot != undefined)
   {
      return undefined;
   }
   while(r < Equipment.chosenChips.length)
   {
      keys.push(Equipment.chosenChips[r] != undefined ? String(Equipment.chosenChips[r]) : "");
      r++;
   }
   plugin.Remember(Equipment.CHIPS_MEMORY, keys.join("|"));
};

// the chips kept for a family when the last menu left it, those its rows still have
Equipment.keptChips = function(family)
{
   var plugin = Equipment.plugin();
   var rows = family != undefined ? Equipment.chipRowsOf(family) : undefined;
   var keys = rows != undefined && plugin != undefined && plugin.Recall != undefined ? String(plugin.Recall(Equipment.CHIPS_MEMORY)).split("|") : [];
   var chosen = [];
   var r = 0;
   var c;
   if(keys[0] != family)
   {
      return chosen;
   }
   keys.shift();
   while(r < keys.length && r < rows.length)
   {
      c = 0;
      while(keys[r] != "" && c < rows[r].length)
      {
         if(rows[r][c].key == keys[r])
         {
            chosen[r] = keys[r];
         }
         c++;
      }
      r++;
   }
   return chosen;
};

Equipment.chipsLeaveRows = function()
{
   var lists = Equipment.menu.inventoryLists;
   var flag = Equipment.categoryEntry().flag;
   var entries = lists.itemList.entryList;
   var rows = [];
   var i = 0;
   while(i < entries.length)
   {
      if(lists._typeFilter.isMatch(entries[i], flag))
      {
         rows.push(entries[i]);
      }
      i++;
   }
   Equipment.chipFilter.applyFilter(rows);
   return rows.length > 0;
};

Equipment.startRows = function(config)
{
   var lists = Equipment.menu.inventoryLists;
   Equipment.chosenChips = Equipment.categoryEntry() != undefined ? Equipment.keptChips(Equipment.chipFamily(Equipment.categoryEntry().flag)) : [];
   Equipment.slotChips = [];
   // a new category gets its list in showItemsList, its subcategories follow it
   lists.equipmentShowItemsList = lists.showItemsList;
   lists.showItemsList = function()
   {
      Equipment.categoryShown();
      this.equipmentShowItemsList();
      Equipment.onCategoryChange();
   };
   // with subcategories off the place still holds the chip of a slot filter
   Equipment.chips = lists.panelContainer.createEmptyMovieClip("equipmentChips", lists.panelContainer.getNextHighestDepth());
   lists.addEventListener("categoryChange", Equipment, "onCategoryChange");
   lists.addEventListener("itemHighlightChange", Equipment, "passNew");
   if(Equipment.settings.subcategories)
   {
      lists.itemList.listEnumeration.addFilter(Equipment.chipFilter);
   }
   Equipment.showChips();
   // a chest's and a shop's list widens over its first frames too, the Junk chip of ALL came out big and centred there
   Equipment.watchStrip();
};

// a slot filter of the panel gives way to the category a player picks, the rows of chips start empty
Equipment.categoryShown = function()
{
};

Equipment.onCategoryChange = function(event)
{
   var family = Equipment.chipFamily(Equipment.categoryEntry().flag);
   var changed = family != Equipment.chipsFamily;
   if(changed)
   {
      Equipment.chosenChips = [];
   }
   Equipment.dropKeyChip();
   Equipment.showChips();
   if(changed)
   {
      Equipment.keepChips();
   }
};

// The strip pushes the list down by its height and SkyUI fits the list between it and the bottom bar again.
// It opens for a category that has subcategories and for the filter of a slot, and is gone otherwise. It's two lines
// high when the junk button has a line of its own under the chips
Equipment.openStrip = function(open, lines)
{
   var list = Equipment.menu.inventoryLists.itemList;
   // the list opens with no room for the strip. Taken for a change, the first closing gave the list 30 px it never
   // lost, and a skin with no call that fits the list (Dragonborn UI, Vel'dun UI) drew a row over its bottom bar
   var had = Equipment.number(Equipment.roomHigh);
   var high = open ? Equipment.STRIP_HIGH * (lines > 1 ? lines : 1) : 0;
   var top = list._y - had;
   if(high == had)
   {
      return top;
   }
   Equipment.roomHigh = high;
   Equipment.holdBackdrops(list, had, high);
   list._y = top + high;
   // menus made on SkyUI 5 like Vel'dun UI have no call that fits the list again, the list is cut by hand there
   if(Equipment.menu.updateDynamicListHeight != undefined)
   {
      Equipment.menu.updateDynamicListHeight();
   }
   else if(Equipment.number(list.listHeight) > 0)
   {
      list.listHeight += had - high;
   }
   else if(list.entryHeight > 0)
   {
      // Nordic UI's chest and shop list has no height of its own (its background is gone), the height it got was
      // NaN and no row showed under the Junk chip of ALL. Its count of rows gives up what the strip takes
      list._maxListIndex = Math.max(1, list._maxListIndex - Math.round((high - had) / list.entryHeight));
   }
   Equipment.fitRows(list);
   return top;
};

// A skin can lay a picture of the whole screen's height inside the list (Edge UI), it went down with the list and left
// the top of the screen bare on a page with subcategories. What in the list reaches far above its rows is such a
// picture, found while the list stands at home, and it stays where it was on the screen as the list moves
Equipment.holdBackdrops = function(list, had, high)
{
   var part;
   var box;
   for(var name in list)
   {
      part = list[name];
      if(!(part instanceof MovieClip))
      {
         continue;
      }
      if(had == 0 && part.equipmentBackdrop == undefined)
      {
         box = part.getBounds(list);
         part.equipmentBackdrop = box.yMin < -Equipment.STRIP_HIGH && box.yMax > box.yMin;
      }
      if(part.equipmentBackdrop == true)
      {
         part._y -= high - had;
      }
   }
};

// SkyUI counts the rows that fit only when the columns are laid out, a new height alone keeps the old count. Once the
// columns were laid out before the strip opened, the last row hung under the bottom bar
Equipment.fitRows = function(list)
{
   if(list.entryHeight > 0 && Equipment.number(list.listHeight) > 0)
   {
      list._maxListIndex = Math.floor(list.listHeight / list.entryHeight + 0.05);
   }
   list.requestUpdate();
};

// a slot filter shows in the strip as a word of its own, a press on it lets the filter go
Equipment.showChips = function()
{
   var lists = Equipment.menu.inventoryLists;
   var chips = Equipment.chips;
   var family = Equipment.chipFamily(Equipment.categoryEntry().flag);
   var rows = family == undefined || !Equipment.settings.subcategories || Equipment.chipRowsOf(family) == undefined ? [] : Equipment.chipRowsOf(family);
   var label = lists.categoryLabel;
   var room = Equipment.stripRoom();
   var left = room.left;
   var right = room.right;
   var junk = Equipment.junkButtonWanted();
   var chipped = rows.length > 0 || Equipment.activeSlot != undefined;
   var lines = 0;
   var top;
   var made;
   if(chips == undefined)
   {
      return undefined;
   }
   Equipment.stripRight = right;
   Equipment.clearChips();
   Equipment.chipsFamily = family;
   chips._xscale = chips._yscale = 100;
   chips._x = left;
   // The widest strip is fitted to the width of the list and every category uses its size, so the words keep one size
   // from tab to tab. Where one line would make them this much smaller each group gets a line of its own. A list that
   // moves after the first measure (a station's under Edge UI and Dragonborn UI) gets measured again, the first measure
   // there left the words at a seventh of their size
   if(Equipment.stripScale == undefined || Math.abs(right - left - Equipment.number(Equipment.stripMeasured)) > Equipment.STRIP_REMEASURE)
   {
      Equipment.stripMeasured = right - left;
      Equipment.layChips(Equipment.CHIP_ROWS.armor, 0, false, false);
      Equipment.stripScale = Equipment.fitScale(chips._width, right - left);
      Equipment.chipLines = Equipment.stripScale < Equipment.CHIP_LINES_BELOW && Equipment.CHIP_ROWS.armor.length > 1;
      if(Equipment.chipLines)
      {
         Equipment.clearChips();
         Equipment.layChips(Equipment.CHIP_ROWS.armor, 0, false, true);
         Equipment.stripScale = Equipment.fitScale(chips._width, right - left);
      }
      Equipment.clearChips();
   }
   if(Equipment.activeSlot != undefined)
   {
      // the filter of the slot leads, the subcategories that split what fits it follow
      made = Equipment.makeChip("slot", Equipment.activeSlot.title + "   ×", Equipment.activeSlot.icon, 0, true, -1, undefined);
      lines = Equipment.layChips(rows, made.wide + Equipment.CHIP_GAP, true, Equipment.chipLines == true);
   }
   else if(chipped)
   {
      lines = Equipment.layChips(rows, 0, false, Equipment.chipLines == true);
   }
   top = Equipment.openStrip(chipped || junk, Math.max(1, lines + (junk ? 1 : 0)));
   // the column names stand above the top of the list, the strip takes the place they had before
   top += lists.itemList.header.getBounds(lists.itemList).yMin;
   // The junk button has a line of its own under the chips, beside them it took their room and made them small. In a
   // category with no chips it's alone on the line
   Equipment.placeJunkButton(junk, top + lines * Equipment.STRIP_HIGH, right);
   chips._xscale = chips._yscale = Math.min(Equipment.stripScale, Equipment.fitScale(chips._width, right - left));
   chips._y = top + lines * Equipment.STRIP_HIGH * (1 - chips._yscale / 100) / 2;
   // a menu that centres the name of the category (Nordic UI) gets the strip centred under it too
   Equipment.stripCentred = Equipment.labelCentred();
   if(Equipment.stripCentred)
   {
      chips._x = Math.max(left, Math.min(right - chips._width, left + (label.textField._width * label._xscale / 100 - chips._width) / 2));
   }
   Equipment.markChips();
};

// Where the strip may stand, left and right in the panel's units. It ends where the box of rows does. Edge UI stands
// its categories in a column beside the list, the strip reaches as far as the names of the columns there, the list
// itself is wider than its rows. SkyUI's own header reaches past the box of its rows, and in a shop the categories
// reach past it too, the junk button stood out of the box. Crafting Categories lists its categories in a column beside
// the rows with no bar over them and no name of the category there, the strip starts where the rows do
Equipment.STRIP_REMEASURE = 4;
Equipment.STRIP_EDGE = 8;
Equipment.stripRoom = function()
{
   var lists = Equipment.menu.inventoryLists;
   var label = lists.categoryLabel;
   var header = lists.itemList.header;
   var left = label._x + label.textField._x;
   var right = lists.categoryList._x + lists.categoryList._width;
   // measured where the strip and the junk button stand, a shop moves that holder off the lists' own corner
   var rowsRight = header != undefined && header.getBounds != undefined ? header.getBounds(lists.panelContainer).xMax : undefined;
   var edge;
   if(rowsRight > 0)
   {
      right = Math.min(rowsRight, lists.itemList.getBounds(lists.panelContainer).xMax);
   }
   if((label == undefined || !(left >= 0) || Equipment.stationStrip && !label._visible) && header != undefined && header.getBounds != undefined)
   {
      left = header.getBounds(lists.panelContainer).xMin;
   }
   // Untarnished UI hangs the name of the category past the screen's edge, the sign of Light was cut there
   edge = {x:Stage.visibleRect.x + Equipment.STRIP_EDGE, y:0};
   if(Equipment.chips != undefined && Equipment.chips._parent != undefined)
   {
      Equipment.chips._parent.globalToLocal(edge);
      left = Math.max(left, edge.x);
   }
   return {left:left, right:right};
};

Equipment.labelCentred = function()
{
   var label = Equipment.menu.inventoryLists.categoryLabel;
   return label != undefined && label._visible != false && label.textField.getTextFormat().align == "center";
};

// A strip laid while the skin still laid out its list or the name of the category is laid again where they stand
// now. A station's list moves after it opens (Edge UI, Dragonborn UI). The inventory's list widens over its first
// frames, a strip measured in the first one came out for a narrower list and went to two lines of bigger words
// until the category changed
Equipment.STRIP_WATCH_FRAMES = 60;
Equipment.STRIP_SETTLE_FRAMES = 3;
Equipment.followStrip = function()
{
   var room;
   var seen;
   if(Equipment.stripMeasured == undefined || Equipment.chips == undefined)
   {
      return undefined;
   }
   room = Equipment.stripRoom();
   seen = Math.round(room.right - room.left) + (Equipment.labelCentred() ? " centred" : "");
   // SkyUI widens the list over the first frames of a menu (443 to 546 in one measure), the strip waits till it stands
   if(seen != Equipment.stripSeen)
   {
      Equipment.stripSeen = seen;
      Equipment.stripStill = 0;
      return undefined;
   }
   if(++Equipment.stripStill != Equipment.STRIP_SETTLE_FRAMES)
   {
      return undefined;
   }
   if(Math.abs(room.right - room.left - Equipment.stripMeasured) > Equipment.STRIP_REMEASURE || Equipment.labelCentred() != Equipment.stripCentred)
   {
      Equipment.showChips();
   }
};

Equipment.watchStrip = function()
{
   var watch = Equipment.menu.createEmptyMovieClip("equipmentStripWatch", Equipment.menu.getNextHighestDepth());
   watch.frames = Equipment.STRIP_WATCH_FRAMES;
   watch.onEnterFrame = function()
   {
      Equipment.followStrip();
      if(--this.frames <= 0)
      {
         this.onEnterFrame = undefined;
      }
   };
};

// the size in percent that lets a strip this wide into the room, never above its own
Equipment.CHIP_LINES_BELOW = 60;
Equipment.fitScale = function(wide, room)
{
   // no room yet (a skin with no header at the first layout) is no reason to draw the strip turned over
   return wide > room && wide > 0 && room > 0 ? room / wide * 100 : 100;
};

Equipment.clearChips = function()
{
   var chips = Equipment.chips;
   for(var name in chips)
   {
      if(chips[name] instanceof MovieClip)
      {
         chips[name].removeMovieClip();
      }
   }
   chips.clear();
   Equipment.chipTip._visible = false;
};

// The words of the groups from x on, under a slot filter only those that split what fits the slot. With lines each
// group after the first starts a line of its own under it. Gives back how many lines it took
Equipment.layChips = function(rows, x, splitting, lines)
{
   var chosen = Equipment.chosenNow();
   var room = Equipment.chipRoom(rows, chosen);
   var start = x;
   var line = 0;
   var used = false;
   var r = 0;
   var c;
   var made;
   var first;
   var chip;
   while(r < rows.length)
   {
      c = 0;
      first = true;
      if(lines && used && !(r > 0 && rows[r - 1].sharesLine == true))
      {
         line++;
         x = start;
         used = false;
      }
      while(c < rows[r].length)
      {
         chip = rows[r][c];
         c++;
         if(splitting && !Equipment.splitsSlot(chip.key))
         {
            continue;
         }
         if(x > start || x > 0 && line == 0)
         {
            Equipment.separator(Equipment.chips, x - Equipment.CHIP_GAP / 2, first ? Equipment.GROUP_SEPARATOR : Equipment.SEPARATOR, line);
         }
         made = Equipment.makeChip(chip.key, Equipment.translated(chip), chip.icon, x, chosen[r] == chip.key, r, chip.key, chip.tint);
         made._y = line * Equipment.STRIP_HIGH;
         // a chip that's alone never adds up with the others, so it never reads as empty with them
         if(!made.chosen && chip.alone != true && room[r] != undefined && !Equipment.anyHolds(room[r], chip.key))
         {
            made.empty = true;
            Equipment.drawChip(made, false);
         }
         x += made.wide + Equipment.CHIP_GAP;
         first = false;
         used = true;
      }
      r++;
   }
   return line + 1;
};

// A type and a body part add up, Light with Head where no light helmet is leaves nothing and a press there lets the
// other group go. Such a chip is drawn faint, so the two groups read as one choice each that add up. For each group,
// the rows the other groups' chosen chips keep, nothing for a group whose others have nothing chosen. Under a slot's
// filter no group lets another go. The station's first group picks weapons or armor and is never faint
Equipment.chipRoom = function(rows, chosen)
{
   var lists = Equipment.menu.inventoryLists;
   var entries = lists.itemList != undefined ? lists.itemList.entryList : undefined;
   var flag = Equipment.categoryEntry() != undefined ? Equipment.categoryEntry().flag : undefined;
   var room = [];
   var r = 0;
   var o;
   var i;
   var keep;
   while(rows != undefined && r < rows.length && Equipment.activeSlot == undefined && entries != undefined)
   {
      o = 0;
      while(o < chosen.length && (o == r || chosen[o] == undefined))
      {
         o++;
      }
      if(o < chosen.length && !(Equipment.chipsFamily == "gear" && r == 0))
      {
         room[r] = [];
         i = 0;
         while(i < entries.length)
         {
            keep = lists._typeFilter.isMatch(entries[i], flag);
            o = 0;
            while(keep && o < chosen.length)
            {
               keep = o == r || chosen[o] == undefined || Equipment.chipHolds(chosen[o], entries[i]);
               o++;
            }
            if(keep)
            {
               room[r].push(entries[i]);
            }
            i++;
         }
      }
      r++;
   }
   return room;
};

Equipment.anyHolds = function(entries, key)
{
   var i = 0;
   while(i < entries.length)
   {
      if(Equipment.chipHolds(key, entries[i]))
      {
         return true;
      }
      i++;
   }
   return false;
};

// a subcategory splits what fits the slot when it holds some of it and not all of it
Equipment.splitsSlot = function(key)
{
   var lists = Equipment.menu.inventoryLists;
   var entries = lists.itemList.entryList;
   var flag = Equipment.categoryEntry().flag;
   var fit = 0;
   var held = 0;
   var i = 0;
   while(i < entries.length)
   {
      if(lists._typeFilter.isMatch(entries[i], flag) && Equipment.fits(entries[i], Equipment.activeSlot))
      {
         fit++;
         held += Equipment.chipHolds(key, entries[i]) ? 1 : 0;
      }
      i++;
   }
   return held > 0 && held < fit;
};

// a thin upright line between two subcategories, taller and lighter between two groups
Equipment.separator = function(chips, x, share, line)
{
   var high = Equipment.STRIP_HIGH * share;
   var top = Equipment.number(line) * Equipment.STRIP_HIGH;
   chips.lineStyle(1, Equipment.inkOf("chip"), share == Equipment.GROUP_SEPARATOR ? 45 : 22, true);
   chips.moveTo(x, top + (Equipment.STRIP_HIGH - high) / 2);
   chips.lineTo(x, top + (Equipment.STRIP_HIGH + high) / 2);
   chips.lineStyle();
};

Equipment.makeChip = function(name, words, icon, x, chosen, row, key, tint)
{
   var chip = Equipment.chips.createEmptyMovieClip("chip_" + name + "_" + row, Equipment.chips.getNextHighestDepth());
   var slot = row < 0;
   var color = slot ? Equipment.accentInk() : Equipment.inkOf("chip");
   var sign = chip.createEmptyMovieClip("sign", 2);
   var text = Equipment.writeLine(chip, "words", 1, words.toUpperCase(), Equipment.CHIP_TEXT, color);
   Equipment.drawIcon(sign, icon, 0, (Equipment.STRIP_HIGH - Equipment.CHIP_ICON) / 2, Equipment.CHIP_ICON, tint != undefined ? tint : color, 100);
   chip.tinted = tint != undefined;
   text._x = Equipment.CHIP_ICON + Equipment.ICON_TO_WORD;
   chip._x = x;
   chip.wide = text._x + text._width;
   chip.chosen = chosen;
   chip.row = row;
   chip.key = key;
   chip.label = words;
   chip.color = color;
   text._y = (Equipment.STRIP_HIGH - text._height) / 2;
   Equipment.drawChip(chip, false);
   chip.onRollOver = function()
   {
      Equipment.drawChip(this, true);
      Equipment.showChipWeight(this);
   };
   chip.onRollOut = chip.onReleaseOutside = function()
   {
      Equipment.drawChip(this, false);
      Equipment.hideChipWeight();
   };
   chip.onPress = function()
   {
      Equipment.pressChip(this);
   };
   return chip;
};

// dim words, lighter under the pointer, the chosen one bright and underlined. The clear box takes the presses
Equipment.drawChip = function(chip, lit)
{
   var line = chip.words._y + chip.words._height - Equipment.UNDERLINE_BELOW;
   chip.clear();
   chip.beginFill(0, 0);
   chip.moveTo(0, 0);
   chip.lineTo(chip.wide, 0);
   chip.lineTo(chip.wide, Equipment.STRIP_HIGH);
   chip.lineTo(0, Equipment.STRIP_HIGH);
   chip.lineTo(0, 0);
   chip.endFill();
   chip.words._alpha = chip.chosen ? 100 : (lit ? Equipment.CHIP_LIT : (chip.empty ? Equipment.CHIP_EMPTY : Equipment.CHIP_DIM));
   // a coloured sign keeps more of its colour while dim, the colour is what it says
   chip.sign._alpha = chip.chosen || lit ? 100 : (chip.empty ? Equipment.CHIP_EMPTY : (chip.tinted ? Equipment.CHIP_LIT : Equipment.CHIP_DIM));
   if(chip.chosen)
   {
      chip.lineStyle(2, chip.color, 85, true);
      chip.moveTo(chip.words._x + 1, line);
      chip.lineTo(chip.wide - 1, line);
      chip.lineStyle();
   }
};

// The game brings the list up to date through InvalidateListData of the lists, after an equip and the like. That call
// runs the same InvalidateData of the list, counts the categories again and tells the menu. A filter of the panel goes
// the same way, through passRows since I4 Improved held these back
Equipment.refilter = function()
{
   var lists = Equipment.menu.inventoryLists;
   Equipment.passRows(lists.itemList, function()
   {
      if(lists.InvalidateListData != undefined)
      {
         lists.InvalidateListData();
         return undefined;
      }
      lists.itemList.InvalidateData();
   });
};

Equipment.pressChip = function(chip)
{
   var lists = Equipment.menu.inventoryLists;
   if(lists.itemList.disableInput || lists.categoryList.disableInput)
   {
      return undefined;
   }
   if(chip.row < 0)
   {
      Equipment.dropFilter();
   }
   else
   {
      Equipment.pickChip(Equipment.chosenNow(), Equipment.chipRowsOf(Equipment.chipsFamily), chip.row, chip.key);
      Equipment.leaveRowsOpen(chip.row);
   }
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
   Equipment.showChips();
   Equipment.keepChips();
   lists.itemList.selectedIndex = -1;
   lists.itemList.scrollPosition = 0;
   Equipment.refilter();
};

// A press on a chip of a group: the chosen one again lets the group go, another takes its place. A chip that's alone
// lets the other groups go, and goes itself when another group gets a chip
Equipment.pickChip = function(chosen, rows, row, key)
{
   var alone;
   var r = 0;
   chosen[row] = chosen[row] == key ? undefined : key;
   if(chosen[row] == undefined)
   {
      return undefined;
   }
   alone = Equipment.chipAlone(rows, row, key);
   while(rows != undefined && r < rows.length)
   {
      if(r != row && (alone || Equipment.chipAlone(rows, r, chosen[r])))
      {
         chosen[r] = undefined;
      }
      r++;
   }
};

// Groups add up, and a pick that leaves no row at all with the other groups lets them go: Clothing chosen and then
// Other of the slots left an empty list, and Clothing looked stuck
Equipment.leaveRowsOpen = function(row)
{
   var chosen = Equipment.chosenNow();
   var r = 0;
   if(Equipment.activeSlot != undefined || chosen[row] == undefined || Equipment.chipsLeaveRows())
   {
      return undefined;
   }
   while(r < chosen.length)
   {
      if(r != row)
      {
         chosen[r] = undefined;
      }
      r++;
   }
};

Equipment.chipAlone = function(rows, row, key)
{
   var group = rows != undefined ? rows[row] : undefined;
   var c = 0;
   while(key != undefined && group != undefined && c < group.length)
   {
      if(group[c].key == key)
      {
         return group[c].alone == true;
      }
      c++;
   }
   return false;
};

// for tests, chooses a chip of a row by its key the way a press does, "" lets the row go
Equipment.chooseChip = function(told)
{
   var parts = String(told).split(",");
   var row = Number(parts[0]);
   var chosen = Equipment.chosenNow();
   // goes the way a press does, a set straight into the row left a station's second row chosen under no chips
   if(parts[1] == "" ? chosen[row] != undefined : chosen[row] != parts[1])
   {
      Equipment.pickChip(chosen, Equipment.chipRowsOf(Equipment.chipsFamily), row, parts[1] == "" ? chosen[row] : parts[1]);
   }
   Equipment.showChips();
   Equipment.keepChips();
   Equipment.refilter();
};

// Keys walk the subcategories too. Up on the list's first row, or with no row picked, goes up to the strip, Left and
// Right walk its chips, Enter chooses the lit one the way a click does, Down or Escape go back to the rows. Tab still
// closes the menu. A pad has its own way there (39-gamepad.as)
Equipment.chipKeys = function(details)
{
   var nav = details.navEquivalent;
   var codes = gfx.ui.NavigationCode;
   var list = Equipment.menu.inventoryLists.itemList;
   var chips;
   if(Equipment.menu._platform != 0 || !Shared.GlobalFunc.IsKeyPressed(details) || !Equipment.listsAnswer())
   {
      return false;
   }
   chips = Equipment.padChips();
   if(Equipment.keyChip == undefined)
   {
      if(nav != codes.UP || chips.length == 0 || !(list.selectedIndex < 0 || list.getListEnumIndex(list.selectedIndex) == 0))
      {
         return false;
      }
      Equipment.lightKeyChip(Equipment.firstKeyChip(chips));
      gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
      return true;
   }
   if(nav == codes.LEFT || nav == codes.RIGHT)
   {
      Equipment.lightKeyChip(Math.max(0, Math.min(chips.length - 1, Equipment.keyChip + (nav == codes.LEFT ? -1 : 1))));
      gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
      return true;
   }
   if(nav == codes.ENTER)
   {
      if(chips[Equipment.keyChip] != undefined)
      {
         Equipment.pressChip(chips[Equipment.keyChip]);
         Equipment.lightKeyChip(Math.min(Equipment.keyChip, Equipment.padChips().length - 1));
      }
      return true;
   }
   if(nav == codes.UP)
   {
      return true;
   }
   Equipment.dropKeyChip();
   // Down steps back onto the rows and nothing more, Escape only leaves the strip, other keys go on as always
   return nav == codes.DOWN || nav == codes.ESCAPE;
};

// the chip the keys start on: the first one chosen, or the first one
Equipment.firstKeyChip = function(chips)
{
   var i = 0;
   while(i < chips.length)
   {
      if(chips[i].chosen)
      {
         return i;
      }
      i++;
   }
   return 0;
};

Equipment.lightKeyChip = function(index)
{
   var chips = Equipment.padChips();
   var old = Equipment.keyChip != undefined ? chips[Equipment.keyChip] : undefined;
   var chip = chips[index];
   if(old != undefined)
   {
      Equipment.drawChip(old, false);
   }
   Equipment.keyChip = chip != undefined ? index : undefined;
   if(Equipment.padRing != undefined)
   {
      Equipment.padRing.clear();
   }
   if(chip != undefined)
   {
      Equipment.drawChip(chip, true);
      if(Equipment.padRing != undefined)
      {
         Equipment.padRingAround(chip, chip.wide, Equipment.STRIP_HIGH);
      }
   }
};

Equipment.dropKeyChip = function()
{
   var chip = Equipment.keyChip != undefined ? Equipment.padChips()[Equipment.keyChip] : undefined;
   if(chip != undefined)
   {
      Equipment.drawChip(chip, false);
   }
   Equipment.keyChip = undefined;
   if(Equipment.padRing != undefined && Equipment.menu._platform == 0)
   {
      Equipment.padRing.clear();
   }
};

// for tests, a key handed to the menu the way SkyUI's input hands it, by the name of its navigation code ("UP",
// "ENTER"). Simulated keys reach the menus only with a name of the game's controls, arrows have none there
Equipment.pressNav = function(name)
{
   Equipment.menu.handleInput({value:"keyDown", navEquivalent:gfx.ui.NavigationCode[String(name).toUpperCase()], code:0}, []);
};

// the chip of a slot filter has no key of its own, tests call it "slot"
Equipment.chipKey = function(chip)
{
   return chip.key != undefined ? chip.key : "slot";
};

// for tests, the middle of the chip with this key as aimedX, aimedY, and what a press there would land on.
// Papyrus hands strings over in the case the game met them first ("Head" for "head"), so case doesn't count
Equipment.aimChip = function(key)
{
   var name;
   var chip;
   var point;
   var share;
   Equipment.aimedX = Equipment.aimedY = -1;
   for(name in Equipment.chips)
   {
      chip = Equipment.chips[name];
      if(chip instanceof MovieClip && chip.wide != undefined && Equipment.chipKey(chip).toLowerCase() == String(key).toLowerCase())
      {
         point = {x:chip.wide / 2, y:Equipment.STRIP_HIGH / 2};
         chip.localToGlobal(point);
         share = Equipment.screenShare(point.x, point.y);
         Equipment.aimedX = share.x;
         Equipment.aimedY = share.y;
         Equipment.aimedTop = String(Mouse.getTopMostEntity(point.x, point.y, true));
         return undefined;
      }
   }
};

// for tests, every chip in sight with its box in shares of the screen, chosen or not, and whether a press on
// its middle reaches it or something of another menu file lies over it, then the rows of the list
Equipment.chipsReport = function(note)
{
   var lines = [];
   var name;
   var chip;
   var from;
   var to;
   var top;
   for(name in Equipment.chips)
   {
      chip = Equipment.chips[name];
      if(chip instanceof MovieClip && chip.wide != undefined)
      {
         from = {x:0, y:0};
         to = {x:chip.wide, y:Equipment.STRIP_HIGH};
         chip.localToGlobal(from);
         chip.localToGlobal(to);
         top = String(Mouse.getTopMostEntity((from.x + to.x) / 2, (from.y + to.y) / 2, true));
         lines.push(Equipment.chipKey(chip) + (chip.chosen ? "*" : "") + (chip.empty ? "~" : "") + " " + Equipment.tenth(Equipment.screenShare(from.x, from.y).x * 100) + "-" + Equipment.tenth(Equipment.screenShare(to.x, to.y).x * 100) + "%" + (top.indexOf(String(chip)) == 0 ? "" : " UNDER " + top));
      }
   }
   lines.reverse();
   var list = Equipment.menu.inventoryLists.itemList.getBounds(_root);
   to = {x:Equipment.junkButton.wide, y:0};
   Equipment.junkButton.localToGlobal(to);
   skse.Log("PANELTEST chips " + note + ": " + lines.join(", ") + "; strip " + (Equipment.chips._visible ? "shown" : "hidden") + ", rows " + Equipment.menu.inventoryLists.itemList.listEnumeration.size() + ", category " + Equipment.categoryEntry().text + ", size " + Math.round(Equipment.stripScale) + "% in " + (Equipment.chipLines ? "lines" : "one line") + ", left " + Math.round(Equipment.stripRoom().left) + ", right " + Math.round(Equipment.stripRight) + ", measured in " + Math.round(Equipment.stripMeasured) + ", at " + Math.round(Equipment.chips._x) + (Equipment.stripCentred ? " centred" : "") + ", on the stage list box to " + Math.round(list.xMax) + (Equipment.junkButton._visible ? ", junk button to " + Math.round(to.x) : ""));
};

// for tests, how many rows of the open category each of its chips would keep, nothing chosen changes
Equipment.chipCounts = function(note)
{
   var lists = Equipment.menu.inventoryLists;
   var entries = lists.itemList.entryList;
   var flag = Equipment.categoryEntry().flag;
   var rows = Equipment.chipRowsOf(Equipment.chipFamily(flag));
   var counts = [];
   var r = 0;
   var c;
   var i;
   var held;
   while(rows != undefined && r < rows.length)
   {
      c = 0;
      while(c < rows[r].length)
      {
         held = 0;
         i = 0;
         while(i < entries.length)
         {
            held += lists._typeFilter.isMatch(entries[i], flag) && Equipment.chipHolds(rows[r][c].key, entries[i]) ? 1 : 0;
            i++;
         }
         counts.push(rows[r][c].key + " " + held);
         c++;
      }
      r++;
   }
   skse.Log("PANELTEST counts " + note + " (" + Equipment.categoryEntry().text + "): " + counts.join(", "));
};

// for tests, the list scrolled as far down as it goes
Equipment.scrollListEnd = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   list.scrollPosition = list.maxScrollPosition;
};

// for tests, how many rows the list draws for its height, and where the last one ends against the top of
// what the bottom bar shows
Equipment.listFitReport = function(note)
{
   var list = Equipment.menu.inventoryLists.itemList;
   var last = list.getClipByIndex(list._listIndex - 1);
   var end = {x:0, y:last != undefined ? last._height : 0};
   var bar = {x:0, y:Equipment.barTop()};
   if(last != undefined)
   {
      last.localToGlobal(end);
   }
   Equipment.menu.localToGlobal(bar);
   skse.Log("PANELTEST list fit " + note + ": height " + Math.round(list.listHeight) + ", row " + list.entryHeight + ", fit " + list._maxListIndex + ", drawn " + list._listIndex + ", last row ends " + Math.round(end.y) + ", bottom bar at " + Math.round(bar.y) + (end.y > bar.y + 1 ? " UNDER THE BAR" : ""));
};

// for tests, the category with this flag is pressed, the sides of a chest or a shop have flags of their own
Equipment.chooseFlag = function(flag)
{
   var index = Equipment.categoryWith(Number(flag));
   skse.Log("PANELTEST category flag " + flag + " is at " + index);
   if(index >= 0)
   {
      Equipment.chooseCategory(index);
   }
};

// for tests, the middle of the category with this flag in its bar as aimedX, aimedY, for a press of the
// pointer. A category the script pressed was not the one the inventory opened on the next time
Equipment.aimCategoryWith = function(flag)
{
   var list = Equipment.menu.inventoryLists.categoryList;
   var index = Equipment.categoryWith(Number(flag));
   var clip = index >= 0 && list.getClipByIndex != undefined ? list.getClipByIndex(index) : undefined;
   var point;
   var share;
   Equipment.aimedX = Equipment.aimedY = -1;
   if(clip == undefined)
   {
      return undefined;
   }
   point = {x:clip._width / 2, y:clip._height / 2};
   clip.localToGlobal(point);
   share = Equipment.screenShare(point.x, point.y);
   Equipment.aimedX = share.x;
   Equipment.aimedY = share.y;
};

// for tests, a category of the list is pressed by its place in the bar
Equipment.chooseCategory = function(index)
{
   Equipment.menu.inventoryLists.categoryList.onItemPress(Number(index), 0);
};
