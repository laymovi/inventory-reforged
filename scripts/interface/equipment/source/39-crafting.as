// The panel at a crafting station that makes or betters gear: the forge, a tanning rack, a workbench or a grindstone,
// the enchanter, and any station a mod builds on them. The character stands right of the list with the slots of the
// inventory round it, filled with what the player wears. A piece of the list goes on for show only when the player
// asks for it in the menu of its row, the plugin draws it on the body and puts it in its slot without it ever being made
// or worn. Taken off by the same menu, by the menu of its slot, or by trying another piece on the same slots. A station
// that makes nothing to wear (a cooking pot, a smelter) gets no panel. All of it comes off as the menu closes
Equipment.CRAFTING_KINDS = {ConstructibleObject:true, Smithing:true, EnchantConstruct:true};
// how long the panel waits for the station's rows, a big list of a crafting mod fills slowly at a low frame rate
Equipment.CRAFTING_WAIT_MS = 3000;
Equipment.TRIED_GAP = 6;
Equipment.TRIED_SIZE = 14;

Equipment.startCrafting = function(menu)
{
   var list = menu.InventoryLists.itemList;
   var holder = menu.createEmptyMovieClip("equipmentCraftingWait", menu.getNextHighestDepth());
   Equipment.menu = menu;
   // the inventory's names for the parts the panel finds by them
   menu.inventoryLists = menu.InventoryLists;
   if(menu.bottomBar == undefined)
   {
      menu.bottomBar = menu.BottomBarInfo;
   }
   Equipment.readSettings();
   if(Equipment.plugin() == undefined || Equipment.plugin().Worn == undefined || !Equipment.settings.panel || Equipment.CRAFTING_KINDS[menu._subtypeName] != true)
   {
      return undefined;
   }
   // the rows come a few frames after the menu, a station whose rows hold nothing to wear stays as SkyUI has it
   holder.since = getTimer();
   holder.onEnterFrame = function()
   {
      var gear = Equipment.craftingGear(list.entryList);
      if(gear == undefined && getTimer() - this.since < Equipment.CRAFTING_WAIT_MS)
      {
         return undefined;
      }
      this.onEnterFrame = undefined;
      if(gear == true)
      {
         Equipment.buildCrafting();
      }
   };
};

// true when the rows hold armor or a weapon, false when they hold only other things, undefined while there are none
Equipment.craftingGear = function(entries)
{
   var i = 0;
   if(entries == undefined || entries.length == 0)
   {
      return undefined;
   }
   while(i < entries.length)
   {
      if(Equipment.triable(entries[i]))
      {
         return true;
      }
      i++;
   }
   return false;
};

Equipment.triable = function(entry)
{
   return entry != undefined && (entry.formType == Equipment.ARMOR || entry.formType == Equipment.WEAPON);
};

// a row whose piece can be tried on now, the plugin tells nothing of tried pieces on a game it couldn't hook
Equipment.tryable = function(entry)
{
   return Equipment.canTryOn == true && Equipment.triable(entry);
};

// The panel of the inventory, its slots, the item window over the list with the card and model of a row (SkyUI puts
// them over the room of the character here), the tabs of the companions and the look sheet. In this menu the window
// comes up at once over a row whatever Pops up says, the card has no other place to go
Equipment.buildCrafting = function()
{
   var menu = Equipment.menu;
   var list = menu.inventoryLists.itemList;
   var i = 0;
   // the inventory's names for the parts the panel finds by them
   menu.itemCard = menu.ItemInfo;
   menu.mouseRotationRect = menu.MouseRotationRect;
   // Crafting Categories puts its tree of categories in place of the hidden bar after the menu opens. Kept once, the
   // panel read the bar's ALL whatever page was picked, so the list is asked each time
   menu.inventoryLists.addProperty("categoryList", function()
   {
      return this.CategoriesList;
   }, function()
   {
   });
   Equipment.readSubject();
   Equipment.readSquash();
   // a skin on light paper (Dear Diary) writes the card in dark ink, the window becomes paper here too. A station's
   // config can come after the panel, its paper is read once it does
   Equipment.readSkin(menu._config);
   Equipment.builtWithConfig = menu._config != undefined;
   Equipment.stationConfigs = 0;
   menu.stationSetConfig = menu.setConfig;
   menu.setConfig = function(a_config)
   {
      this.stationSetConfig(a_config);
      Equipment.stationConfigs++;
      Equipment.readSkin(a_config);
      Equipment.showWindow();
   };
   Equipment.buildLayers();
   // the parts of the inventory's slots that mean nothing here: strips, drag and drop. The eyes stay for the worn pieces
   Equipment.hasPieces = function()
   {
      return false;
   };
   Equipment.fits = function()
   {
      return false;
   };
   // A tried piece always shows, it's on for a look. Its slot has no eye then, the worn piece under it keeps its own and
   // gets it back with Take off
   Equipment.stationCanToggle = Equipment.canToggle;
   Equipment.canToggle = function(slot)
   {
      var entry = slot != undefined ? slot.entries[0] : undefined;
      return !(entry != undefined && entry.tried == true) && Equipment.stationCanToggle(slot);
   };
   Equipment.click = Equipment.clickCrafting;
   Equipment.press = Equipment.clickCrafting;
   Equipment.switchCompanion = Equipment.switchAtStation;
   Equipment.popUpNow = function()
   {
      return Equipment.WINDOW_AT_ONCE;
   };
   Equipment.hover = function(slot, over)
   {
      slot.hovered = over;
      Equipment.drawFrame(slot);
   };
   // the crafting menu has no fade the inventory waits for
   Equipment.listsAnswer = function()
   {
      var lists = Equipment.menu.inventoryLists;
      return !lists.itemList.disableInput && !lists.itemList.disableSelection && !Equipment.inspecting;
   };
   Equipment.readCompanions();
   // the station's title stands over the character's room, the room starts under it and the tabs
   Equipment.titleHigh = Equipment.stationTitleHigh();
   Equipment.companionsRoom = Equipment.number(Equipment.companionsRoom) + Equipment.titleHigh;
   Equipment.build();
   Equipment.layout();
   Equipment.buildWindow(true);
   Equipment.watchLeaveRows();
   Equipment.buildContext();
   while(i < Equipment.SLOTS.length)
   {
      Equipment.SLOTS[i].box.onPress = function()
      {
         Equipment.clickCrafting(this.slot);
      };
      Equipment.SLOTS[i].box.onPressAux = function()
      {
         Equipment.clickCrafting(this.slot);
      };
      i++;
   }
   Equipment.buildHero();
   Equipment.buildCompanions();
   Equipment.placeStationTitle();
   Equipment.buildLook();
   // the look button keeps after the station's hints whenever they change, the pad's words too
   Equipment.followHints();
   Equipment.takeIngredients();
   list.addEventListener("itemPressAux", Equipment, "craftingRowPress");
   list.stationUpdateList = list.UpdateList;
   list.UpdateList = function()
   {
      this.stationUpdateList();
      Equipment.followStationEdge();
   };
   Equipment.watchStationEdge();
   Equipment.startStationChips();
   Equipment.markTriedRows();
   Equipment.fillCraftingSlots();
   Equipment.buildCraftingPad(menu);
   Equipment.crafting = true;
};

// A gamepad walks the panel as in the inventory: the click of the right stick moves between the list and the slots, a
// hold of it on a row of armor or a weapon opens the row's menu, A on a slot takes its tried piece off. X stays the
// station's own, it crafts here. The station draws its bar in UpdateButtonText, the pad's words go in after it
Equipment.buildCraftingPad = function(menu)
{
   menu.stationButtonText = menu.UpdateButtonText;
   menu.updateBottomBar = function()
   {
      this.stationButtonText();
   };
   menu.UpdateButtonText = function()
   {
      this.updateBottomBar(this.inventoryLists.itemList.selectedIndex >= 0);
   };
   Equipment.openRowMenu = function(entry)
   {
      if(!Equipment.tryable(entry))
      {
         return false;
      }
      Equipment.craftingRowPress({entry:entry});
      return Equipment.padMenuUp();
   };
   Equipment.padPressCell = function(cell)
   {
      var entry = cell != undefined ? cell.entries[0] : undefined;
      if(entry != undefined && entry.tried == true)
      {
         Equipment.tryOn(entry, false);
         Equipment.padMark();
         Equipment.padHints();
      }
   };
   Equipment.stationPressWords = Equipment.padPressWords;
   Equipment.padPressWords = function(at)
   {
      var cell = at.kind == "slot" ? Equipment.padCell(at) : undefined;
      if(at.kind != "slot")
      {
         return Equipment.stationPressWords(at);
      }
      return cell != undefined && cell.entries[0].tried == true ? Equipment.say("Take off") : undefined;
   };
   Equipment.padHide = function()
   {
   };
   Equipment.padHideWords = function()
   {
      return undefined;
   };
   Equipment.padListHint = function()
   {
      var panel = Equipment.menu.navPanel;
      if(!Equipment.padReady())
      {
         return undefined;
      }
      panel.addButton({text:Equipment.say("Panel"), controls:{keyCode:Equipment.PAD_STICK}});
      if(Equipment.settings.rowMenu && Equipment.tryable(Equipment.menu.inventoryLists.itemList.selectedEntry))
      {
         panel.addButton({text:Equipment.say("Menu (hold)"), controls:{keyCode:Equipment.PAD_STICK}});
      }
      panel.updateButtons(true);
   };
   Equipment.buildPad();
   Equipment.holdCancel(menu);
};

// The rows of a station take their width once its config lays the list out, that can come after the panel stood (Edge
// UI's forge stood its slots by the rows' first width, over half the screen too far). The panel stands anew once the
// list's edge moved
Equipment.EDGE_MOVED = 4;
Equipment.followStationEdge = function()
{
   if(Equipment.frame == undefined || Math.abs(Equipment.listEdge().right - Equipment.number(Equipment.laidEdge)) <= Equipment.EDGE_MOVED)
   {
      return undefined;
   }
   Equipment.relayout();
   Equipment.placeStationTitle();
};

// The subcategories of the inventory over a station's rows. Its categories name kinds (SkyUI's forge: 1 weapons, 2 ammo,
// 4 armor, 8 jewelry) or materials that hold weapons and armor together (Crafting Categories), so the family comes from
// the rows the page shows. A page of both gets a choice of the two first, the chips of the one chosen follow it. The
// station keeps its chips apart from the inventory's
Equipment.STATION_KINDS = [[{key:"weaponsKind", words:"$WEAPONS", fallback:"Weapons", icon:"sword"}, {key:"armorKind", words:"$Armor", fallback:"Armor", icon:"cuirass"}]];
// on a narrow list with a line for each group the two kinds stay on the line of the first group after them
Equipment.STATION_KINDS[0].sharesLine = true;
Equipment.startStationChips = function()
{
   Equipment.CHIPS_MEMORY = "stationChips";
   Equipment.stationStrip = true;
   Equipment.chipFamily = function(flag)
   {
      return Equipment.stationFamily(flag);
   };
   Equipment.chipRowsOf = function(family)
   {
      var chosen = Equipment.chosenNow();
      var kind = family == "gear" && chosen != undefined ? chosen[0] : undefined;
      if(family != "gear")
      {
         return Equipment.CHIP_ROWS[family];
      }
      return kind == "weaponsKind" ? Equipment.STATION_KINDS.concat(Equipment.CHIP_ROWS.weapons) : (kind == "armorKind" ? Equipment.STATION_KINDS.concat(Equipment.CHIP_ROWS.armor) : Equipment.STATION_KINDS);
   };
   Equipment.stationPickChip = Equipment.pickChip;
   Equipment.pickChip = function(chosen, rows, row, key)
   {
      Equipment.stationPickChip(chosen, rows, row, key);
      // the other kind takes its own chips, the ones of the kind before go
      if(Equipment.chipsFamily == "gear" && row == 0)
      {
         chosen.length = 1;
      }
   };
   Equipment.startRows(Equipment.menu._config);
};

// weapons, armor or both among the rows of a category, jewelry alone has no chips
Equipment.stationFamily = function(flag)
{
   var lists = Equipment.menu.inventoryLists;
   var entries = lists.itemList.entryList;
   var weapons = 0;
   var armor = 0;
   var ammo = 0;
   var seen = 0;
   var i = 0;
   while(i < entries.length)
   {
      if(lists._typeFilter.isMatch(entries[i], flag))
      {
         seen++;
         if(entries[i].formType == Equipment.ARMOR && entries[i].weightClass != 4)
         {
            armor++;
         }
         else if(entries[i].formType == Equipment.WEAPON)
         {
            weapons++;
         }
         else if(entries[i].formType == Equipment.AMMO)
         {
            ammo++;
         }
      }
      i++;
   }
   // the page of every row is the station's ALL, it has no chips as the inventory's ALL has none
   if(seen == entries.length && lists.categoryList.entryList.length > 1)
   {
      return undefined;
   }
   // a page of ammo alone (SkyUI's forge has one) has nothing for the weapon chips to split
   weapons += weapons > 0 || armor > 0 ? ammo : 0;
   return weapons > 0 && armor > 0 ? "gear" : (armor > 0 ? "armor" : (weapons > 0 ? "weapons" : undefined));
};

// for tests, the first category of the station whose rows get chips of one of these families as aimedX,
// aimedY for a press of the pointer, and every category's family in the log. Crafting Categories' list of them took
// no press from the script
Equipment.aimChipCategory = function(families)
{
   var list = Equipment.menu.inventoryLists.categoryList;
   var categories = list.entryList;
   var wanted = "," + String(families) + ",";
   var told = [];
   var family;
   var clip;
   var point;
   var share;
   var i = 0;
   Equipment.aimedX = Equipment.aimedY = -1;
   while(i < categories.length)
   {
      family = Equipment.stationFamily(categories[i].flag);
      told.push(categories[i].text + "=" + family);
      clip = list.getClipByIndex != undefined ? list.getClipByIndex(i) : undefined;
      if(family != undefined && wanted.indexOf("," + family + ",") >= 0 && clip != undefined)
      {
         point = {x:clip._width / 2, y:clip._height / 2};
         clip.localToGlobal(point);
         share = Equipment.screenShare(point.x, point.y);
         Equipment.aimedX = share.x;
         Equipment.aimedY = share.y;
         skse.Log("PANELTEST station category " + categories[i].text + " (" + family + ") of " + told.join(", "));
         return undefined;
      }
      i++;
   }
   skse.Log("PANELTEST no station category with chips of " + families + ": " + told.join(", "));
};

// Edge UI's forge widens its list a moment after it opens with no new update of its rows, the slots stood on the rows
// till the first click. The edge is watched for a second after the opening
Equipment.STATION_EDGE_FRAMES = 60;

Equipment.watchStationEdge = function()
{
   var watch = Equipment.under.createEmptyMovieClip("equipmentEdgeWatch", Equipment.under.getNextHighestDepth());
   watch.frames = Equipment.STATION_EDGE_FRAMES;
   watch.onEnterFrame = function()
   {
      Equipment.followStationEdge();
      Equipment.followStrip();
      if(--this.frames <= 0)
      {
         this.onEnterFrame = undefined;
      }
   };
};

// How high the station's title stands, in the panel's units: the line the panel writes for it. A skin's holder of the
// title can hold a whole backdrop (Norden UI), measured by it the character got a room a third of its height
Equipment.stationTitleHigh = function()
{
   var holder = Equipment.menu.MenuDescriptionHolder;
   var probe;
   var high;
   if(holder == undefined || !holder._visible)
   {
      return 0;
   }
   probe = Equipment.writeLine(Equipment.menu, "equipmentTitleProbe", Equipment.menu.getNextHighestDepth(), "Ag", Equipment.STATION_TITLE_TEXT, Equipment.PARCHMENT);
   high = probe._height;
   probe.removeTextField();
   return high > 0 ? high + Equipment.COMPANION_GAP : 0;
};

// The title (Blacksmith Forge: Choose an item to create) in the middle of the character's room, under the tabs of the
// companions. SkyUI keeps its own at the top of the screen in a place of its layout, the tabs lay over it, so the panel
// writes the same words in its own line there and SkyUI's goes clear
Equipment.STATION_TITLE_TEXT = 24;
Equipment.placeStationTitle = function()
{
   var holder = Equipment.menu.MenuDescriptionHolder;
   var field = Equipment.menu.MenuDescription;
   var stage = Equipment.stage;
   var tabs = Equipment.companionPeople != undefined ? Equipment.HERO_TAB_HIGH + 2 * Equipment.COMPANION_GAP : 0;
   var line;
   if(holder == undefined || field == undefined || !(Equipment.titleHigh > 0))
   {
      return undefined;
   }
   line = Equipment.panel.stationTitle;
   if(line == undefined)
   {
      line = Equipment.writeLine(Equipment.panel, "stationTitle", Equipment.COMPANIONS_DEPTH + 1, "", Equipment.STATION_TITLE_TEXT, Equipment.PARCHMENT);
   }
   line.text = field.text;
   line._x = Math.round(stage._x + (stage.touch._width - line._width) / 2);
   line._y = Math.round(Equipment.frame.top + tabs);
   holder._alpha = 0;
};

// SkyUI writes what a recipe asks for in a line under its card, the window's frame ended over it. The line comes into
// the window under the numbers in the colours SkyUI gave it, an ingredient the player lacks stays grey
Equipment.takeIngredients = function()
{
   var menu = Equipment.menu;
   if(menu.UpdateIngredients == undefined || menu.equipmentIngredients != undefined)
   {
      return undefined;
   }
   menu.equipmentIngredients = menu.UpdateIngredients;
   menu.UpdateIngredients = function(title, ingredients, showCount)
   {
      this.equipmentIngredients(title, ingredients, showCount);
      Equipment.copyIngredients();
   };
   Equipment.copyIngredients();
};

Equipment.copyIngredients = function()
{
   var menu = Equipment.menu;
   var field = menu.AdditionalDescription;
   var line = Equipment.window.extra;
   var format = new TextFormat("$EverywhereMediumFont", Equipment.statsText());
   if(line == undefined)
   {
      return undefined;
   }
   if(field == undefined || menu.bItemCardAdditionalDescription == true)
   {
      line.text = "";
      line._visible = false;
      return undefined;
   }
   // SkyUI shows and hides its own line with the card, it stays clear
   menu.AdditionalDescriptionHolder._alpha = 0;
   line._width = Equipment.window.wide - 2 * Equipment.STATS_PAD;
   line.htmlText = Equipment.paper ? Equipment.inksOnPaper(field.htmlText) : field.htmlText;
   // the size and the letters of the window, the colours stay SkyUI's
   line.setTextFormat(format);
   line._visible = line.text != "";
   Equipment.windowLaid = undefined;
   Equipment.showWindow();
};

// SkyUI writes an ingredient the player has in white and one short in grey, on paper they take the inks of the paper
Equipment.INGREDIENT_HAVE = "#FFFFFF";
Equipment.INGREDIENT_SHORT = "#777777";
Equipment.inksOnPaper = function(html)
{
   var text = String(html);
   var have = "#" + Equipment.hex(Equipment.inkOf("value")).toUpperCase();
   var short = "#" + Equipment.hex(Equipment.inkOf("quiet")).toUpperCase();
   text = text.split(Equipment.INGREDIENT_HAVE).join(have).split(Equipment.INGREDIENT_HAVE.toLowerCase()).join(have);
   return text.split(Equipment.INGREDIENT_SHORT).join(short).split(Equipment.INGREDIENT_SHORT.toLowerCase()).join(short);
};

// for tests, the line of the ingredients as the window shows it
Equipment.ingredientsReport = function(note)
{
   var line = Equipment.window.extra;
   skse.Log("PANELTEST ingredients " + note + ": '" + line.text + "' shown " + line._visible + " at " + Math.round(line._y) + " high " + Math.round(line._height) + ", window high " + Math.round(Equipment.window.high) + ", SkyUI's own line seen " + (Equipment.menu.AdditionalDescriptionHolder._alpha > 0) + ", title '" + Equipment.panel.stationTitle.text + "' at " + Math.round(Equipment.panel.stationTitle._y));
};

// A tab of a companion shows them here instead of opening their trade: their gear in the slots, their body on the doll,
// the pieces tried on them. The player's tab shows the player again. Each keeps what was tried on them
Equipment.switchAtStation = function(person)
{
   var plugin = Equipment.plugin();
   var i = 0;
   var tab;
   if(Equipment.companionShown(person) || plugin == undefined || plugin.AtStation == undefined || plugin.AtStation(person.player ? 0 : person.formId) != true)
   {
      return undefined;
   }
   Equipment.readSubject();
   while(Equipment.companions != undefined && Equipment.companions["tab" + i] != undefined)
   {
      tab = Equipment.companions["tab" + i];
      tab.shown = Equipment.companionShown(tab.person);
      Equipment.drawCompanionTab(tab);
      i++;
   }
   Equipment.triedOn = Equipment.canTryOn ? plugin.TryOn() : [];
   Equipment.menu.inventoryLists.itemList.UpdateList();
   Equipment.fillCraftingSlots();
   Equipment.followPlayerAgain();
   Equipment.showWindow();
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

// What the one shown wears and holds, the plugin's rows of it, and the pieces tried on in their slots over what's worn
// there. The item window weighs a row against them
Equipment.fillCraftingSlots = function()
{
   var pieces = Equipment.plugin().Worn();
   var worn = {armor:[]};
   var tried = [];
   var i = 0;
   while(pieces != undefined && i < pieces.length)
   {
      Equipment.fillIcon(pieces[i]);
      if(pieces[i].tried == true)
      {
         tried.push(pieces[i]);
      }
      i++;
   }
   Equipment.addPieces(worn, Equipment.withoutTried(pieces, tried));
   i = 0;
   while(i < tried.length)
   {
      if(tried[i].formType == Equipment.ARMOR)
      {
         worn.armor.push(tried[i]);
      }
      else
      {
         worn.right = tried[i];
         if(worn.left != undefined && worn.left == worn.right)
         {
            worn.left = undefined;
         }
      }
      i++;
   }
   Equipment.place(worn);
   Equipment.wornNow = worn;
   i = 0;
   while(i < Equipment.SLOTS.length)
   {
      Equipment.showSlot(Equipment.SLOTS[i]);
      Equipment.markTriedSlot(Equipment.SLOTS[i]);
      i++;
   }
   Equipment.showModels();
};

// the worn pieces a tried one takes the place of step out: armor on the same body slots, the weapon of the right hand
Equipment.withoutTried = function(pieces, tried)
{
   var kept = [];
   var piece;
   var i = 0;
   var t;
   var covered;
   while(pieces != undefined && i < pieces.length)
   {
      piece = pieces[i];
      i++;
      if(piece.tried == true)
      {
         continue;
      }
      covered = false;
      t = 0;
      while(t < tried.length && !covered)
      {
         covered = tried[t].formType == Equipment.ARMOR && piece.formType == Equipment.ARMOR && (Equipment.number(tried[t].partMask) & Equipment.number(piece.partMask)) != 0 ||
            tried[t].formType == Equipment.WEAPON && piece.formType == Equipment.WEAPON && piece.equipState != Equipment.LEFT_HAND;
         t++;
      }
      if(!covered)
      {
         kept.push(piece);
      }
   }
   return kept;
};

Equipment.isTried = function(entry)
{
   var tried = Equipment.triedOn;
   var i = 0;
   while(entry != undefined && tried != undefined && i < tried.length)
   {
      if(Number(tried[i]) == Number(entry.formId))
      {
         return true;
      }
      i++;
   }
   return false;
};

// a slot showing a piece tried on carries the eye of the rows in its corner
Equipment.markTriedSlot = function(slot)
{
   var box = slot.box;
   var size = Equipment.TRIED_SIZE;
   var entry = slot.entries[0];
   if(box.tried == undefined)
   {
      box.tried = box.createEmptyMovieClip("tried", 7);
      box.tried.hitTestDisable = true;
      Equipment.drawIcon(box.tried, "eye", 0, 0, size, Equipment.GOLD, 100);
   }
   box.tried._x = Equipment.SLOT_SIZE - size - Equipment.EYE_INSET;
   box.tried._y = Equipment.EYE_INSET;
   box.tried._visible = entry != undefined && entry.tried == true;
};

// A slot with a piece tried on has a menu with Take off, the others have nothing to do here
Equipment.clickCrafting = function(slot)
{
   var entry = slot != undefined ? slot.entries[0] : undefined;
   var lines = [];
   var hidden;
   Equipment.closeContext();
   if(entry != undefined && entry.tried == true)
   {
      lines.push({key:"untry", words:Equipment.say("Take off"), icon:"unequip", run:function()
      {
         Equipment.tryOn(entry, false);
      }});
   }
   if(slot != undefined && Equipment.canToggle(slot))
   {
      hidden = Equipment.looksHidden(slot);
      lines.push({key:"hide", words:hidden ? Equipment.say("Show on character") : Equipment.say("Hide on character"), icon:hidden ? "eye" : "eyeShut", run:function()
      {
         Equipment.closeContext();
         Equipment.toggleHidden(slot);
      }});
   }
   if(lines.length > 0)
   {
      Equipment.showContext(lines, slot, undefined);
   }
};

// SkyUI tells a right press on a row as itemPressAux, the row is the selected one by then. Armor and weapons get a
// menu of the row with Try on or Take off
Equipment.craftingRowPress = function(event)
{
   var entry = event.entry;
   var tried;
   if(!Equipment.tryable(entry))
   {
      return undefined;
   }
   tried = Equipment.isTried(entry);
   Equipment.showContext([{key:tried ? "untry" : "try", words:tried ? Equipment.say("Take off") : Equipment.say("Try on"), icon:tried ? "unequip" : "eye", run:function()
   {
      Equipment.tryOn(entry, !tried);
   }}], undefined, entry);
};

// The plugin answers with every piece tried on now, one on the same slots went off. The rows are drawn again for their
// eyes and the slots filled again, the body follows by itself
Equipment.tryOn = function(entry, on)
{
   var tried = Equipment.plugin().TryOn(Number(entry.formId), on);
   Equipment.triedOn = tried != undefined ? tried : [];
   Equipment.closeContext();
   Equipment.menu.inventoryLists.itemList.UpdateList();
   Equipment.fillCraftingSlots();
   gfx.io.GameDelegate.call("PlaySound", [on ? "UIMenuOK" : "UIMenuCancel"]);
};

// the name column of the crafting rows carries the eye of a piece tried on
Equipment.markTriedRows = function()
{
   var row = _global.CraftingListEntry.prototype;
   var tried = Equipment.plugin().TryOn();
   Equipment.canTryOn = tried != undefined;
   Equipment.triedOn = tried != undefined ? tried : [];
   if(row == undefined || row.equipmentFormatName != undefined)
   {
      return undefined;
   }
   row.equipmentFormatName = row.formatName;
   row.formatName = function(field, entry, state)
   {
      this.equipmentFormatName(field, entry, state);
      Equipment.showTried(this, field, entry, state);
   };
   Equipment.menu.inventoryLists.itemList.UpdateList();
};

Equipment.showTried = function(row, field, entry, state)
{
   var eye = row.equipmentTried;
   var size = Equipment.TRIED_SIZE;
   if(!Equipment.isTried(entry))
   {
      eye._visible = false;
      return undefined;
   }
   if(eye == undefined)
   {
      eye = row.createEmptyMovieClip("equipmentTried", row.getNextHighestDepth());
      Equipment.drawIcon(eye, "eye", 0, 0, size, Equipment.GOLD, 100);
   }
   eye._x = Equipment.craftingIconsEnd(row, field, entry, state) + Equipment.TRIED_GAP;
   eye._y = field._y + (field._height - size) / 2;
   eye._visible = true;
};

// A crafting row puts its poison and stolen icons right after the name, the eye of a stolen piece lay on them. It goes
// after those, counted the way SkyUI lays them, and after what other mods put there
Equipment.craftingIconsEnd = function(row, field, entry, state)
{
   var shown = (entry.isPoisoned == true ? 1 : 0) + ((entry.isStolen == true || entry.isStealing == true) && state.showStolenIcon == true ? 1 : 0);
   var wide = row.stolenIcon._width > 0 ? row.stolenIcon._width : field._height;
   var end = field._x + Math.min(field._width, field.textWidth + 4);
   // SkyUI puts the first one 5 after the name and steps a quarter of an icon apart, the eye goes past the last
   if(shown > 0)
   {
      end = field._x + field._width + 5 + (shown - 1) * wide * Equipment.ICON_STEP + wide;
   }
   return Math.max(end, Equipment.number(Equipment.othersEnd(row, field)));
};

// for tests, what is tried on, what the slots show and where the eye of the selected row stands
Equipment.tryReport = function(note)
{
   var list = Equipment.menu.inventoryLists.itemList;
   var entry = list.selectedEntry;
   var row = entry != undefined ? list.getClipByIndex(entry.clipIndex) : undefined;
   var slots = [];
   var i = 0;
   while(Equipment.crafting && i < Equipment.SLOTS.length)
   {
      slots.push(Equipment.SLOTS[i].name + "=" + (Equipment.SLOTS[i].entries.length > 0 ? Equipment.SLOTS[i].entries[0].text + (Equipment.SLOTS[i].entries[0].tried == true ? "(tried)" : "") : "-"));
      i++;
   }
   skse.Log("PANELTEST try on " + note + ": panel " + (Equipment.crafting == true) + ", tried " + Equipment.triedOn.join(",") + ", selected " + entry.text + " form " + entry.formId + " type " + entry.formType + ", eye " + (row.equipmentTried._visible == true) + ", menu " + Equipment.context._visible + ", station " + Equipment.menu._subtypeName + ", title room " + Math.round(Equipment.number(Equipment.titleHigh)) + " (the skin's holder " + Math.round(Equipment.menu.MenuDescriptionHolder._height) + " high), list picture " + Equipment.menu.inventoryLists.getContentBounds().join(",") + " at " + Math.round(Equipment.menu.inventoryLists._x) + ", rows to " + Math.round(Equipment.menu.inventoryLists.itemList.getBounds(Equipment.menu).xMax) + ", entries to " + Math.round(Equipment.entriesBox(Equipment.menu.inventoryLists.itemList, _root).xMax) + " on the stage, list edge " + Math.round(Equipment.listEdge().right) + " in the panel's units, 827 on the stage is " + Math.round(Equipment.toPanel({x:827, y:0}).x) + " and back " + Math.round(Equipment.toStage(Equipment.toPanel({x:827, y:0})).x) + ", squash " + Equipment.squash + ", under at " + Math.round(Equipment.under._x) + " scale " + Math.round(Equipment.under._xscale) + ", frame from " + Math.round(Equipment.frame.left) + " = " + Math.round(Equipment.toStage({x:Equipment.frame.left, y:0}).x) + " on the stage of " + Math.round(Stage.visibleRect.x) + "-" + Math.round(Stage.visibleRect.x + Stage.visibleRect.width) + ", config text " + Equipment.menu._config.Appearance.colors.text.enabled + " paper " + Equipment.paper + " after " + Equipment.stationConfigs + " late configs, the build saw a config " + (Equipment.builtWithConfig == true) + ", card holder in the menu " + (Equipment.menu.itemCard._parent._parent == Equipment.menu) + " at depth " + Equipment.menu.itemCard._parent.getDepth() + " shown " + Equipment.menu.itemCard._parent._visible + " alpha " + Math.round(Equipment.menu.itemCard._parent._alpha) + ", sheet layer at depth " + Equipment.under.getDepth() + ", window layer at " + Equipment.windowLayer.getDepth() + ", slots " + slots.join(" "));
};
