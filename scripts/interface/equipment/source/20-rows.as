Equipment.BETTER = 7195502;
Equipment.WORSE = 14702938;
Equipment.EQUAL = 11579568;
Equipment.ARROW_WIDTH = 9;
Equipment.ARROW_HEIGHT = 7;
Equipment.ICON_GAP = 5;
Equipment.ICON_STEP = 1.25;
Equipment.ITEM_COLUMN = 0;
Equipment.EQUIP_COLUMN = 1;
Equipment.BADGE_INSET = 3;
Equipment.MARK_ROOM = 48;
Equipment.SHORTEST_NAME = 8;
Equipment.NAME_CUT = 3;
// shares of the screen height, a row of SkyUI's is about this high at 1080
Equipment.ROW_TILE_SIZE = 0.031;
Equipment.ROW_TILE_GAP = 1;
Equipment.ROW_TILE_ALPHA = 65;
Equipment.ROWS_TICK = 50;
Equipment.ROWS_QUIET = 150;
Equipment.ROWS_IDLE = 1200;
Equipment.ROW_FADE_STEP = 15;
Equipment.ROW_SIGNS = ["bestIcon", "favoriteIcon", "poisonIcon", "stolenIcon", "enchIcon", "readIcon"];
Equipment.SIGN_SHARE = 0.5;

// wraps the name column of list rows so every row can carry an arrow and the badge of its slot
Equipment.decorateRows = function()
{
   var row = _global.InventoryListEntry.prototype;
   if(row == undefined || row.equipmentFormatName != undefined)
   {
      return undefined;
   }
   if(Equipment.itemRows())
   {
      row.equipmentSignsLayout = row.setSpecificEntryLayout;
      row.setSpecificEntryLayout = function(entry, state)
      {
         this.equipmentSignsLayout(entry, state);
         Equipment.keepSigns(this, state);
      };
   }
   row.equipmentFormatName = row.formatName;
   row.formatName = function(field, entry, state)
   {
      this.equipmentFormatName(field, entry, state);
      this.equipmentNameField = field;
      Equipment.makeRoom(this, field, entry, state);
      Equipment.showQuest(this, field, entry, state);
      Equipment.showJunk(this, field, entry, state);
      Equipment.showDifference(this, field, entry, state);
      Equipment.showBadge(this, entry, state);
      Equipment.showNew(this, field, entry, state);
   };
   Equipment.rowFormat = row.formatName;
};

Equipment.markShown = function(entry)
{
   if(entry.equipmentDifference == undefined || !Equipment.settings.arrows)
   {
      return false;
   }
   return Math.round(entry.equipmentDifference) != 0 || Equipment.settings.equalSign;
};

// where on a row the column of a field ends, nothing when the list has no such column
Equipment.columnEnd = function(field)
{
   var columns = Equipment.menu.inventoryLists.itemList.layout.columnLayoutData;
   var i = 0;
   while(i < columns.length)
   {
      if(columns[i].stageName == field._name)
      {
         return columns[i].x + columns[i].width;
      }
      i++;
   }
   return undefined;
};

// SkyUI cuts a name by its letters and lets a long one run into the next columns, the arrow after it then lay
// under their text. The name of a row that has an arrow is cut shorter until the arrow ends inside its own column.
// The name itself is cut, SkyUI adds the count of a stack after it, so "(37)" stays on a row of arrows
Equipment.makeRoom = function(row, field, entry, state)
{
   var end = Equipment.columnEnd(field);
   var full = entry.text;
   // the words a mod's list takes off after the name stay after the cut name, Completionist's colour of the row
   var markup = Equipment.markupAt(full);
   var keep = markup;
   var room = Equipment.markShown(entry) ? Equipment.MARK_ROOM : 0;
   var over;
   if(end == undefined || room == 0 && !Equipment.junkShown(entry) && !Equipment.questShown(entry))
   {
      return undefined;
   }
   // one cut by the width of a letter close to where it ends, a long name went through the row's whole format a
   // dozen times three letters at a time. The steps after it only finish the cut. It goes from what the row shows:
   // SkyUI cuts a name past its longest itself, a cut of letters it never showed moved nothing
   over = Equipment.afterIcons(row, field, entry, state) + room - end;
   if(over > 0 && field.textWidth > 0 && String(field.text).length > 0)
   {
      keep = Math.max(Equipment.SHORTEST_NAME, Math.min(markup, Math.floor(Math.min(markup, String(field.text).length) - over / (field.textWidth / String(field.text).length)) - 1));
      entry.text = full.substr(0, keep) + "..." + full.substr(markup);
      row.equipmentFormatName(field, entry, state);
   }
   while(Equipment.afterIcons(row, field, entry, state) + room > end && keep > Equipment.SHORTEST_NAME)
   {
      keep -= Equipment.NAME_CUT;
      entry.text = full.substr(0, keep) + "..." + full.substr(markup);
      row.equipmentFormatName(field, entry, state);
   }
   entry.text = full;
};

// a row that can be compared with what's worn says how it compares, an equal one with a grey sign
Equipment.showDifference = function(row, field, entry, state)
{
   if(!Equipment.markShown(entry))
   {
      row.equipmentMark._visible = false;
      return undefined;
   }
   var amount = Math.round(entry.equipmentDifference);
   var mark = row.equipmentMark;
   if(mark == undefined)
   {
      mark = Equipment.createMark(row);
   }
   var better = amount > 0;
   var color = amount == 0 ? Equipment.inkOf("equal") : (better ? Equipment.inkOf("better") : Equipment.inkOf("worse"));
   // a row is drawn again every frame while a list scrolls, the arrow only when it says something else
   if(mark.drawnAmount !== amount || mark.drawnColor !== color)
   {
      mark.arrow.clear();
      if(amount != 0)
      {
         Equipment.drawArrow(mark.arrow, better, color);
      }
      mark.amount._x = amount == 0 ? 0 : Equipment.ARROW_WIDTH + 3;
      mark.amount.text = amount == 0 ? "=" : (better ? "+" : "") + amount;
      mark.amount.textColor = color;
      mark.drawnAmount = amount;
      mark.drawnColor = color;
   }
   mark._x = Equipment.afterIcons(row, field, entry, state);
   mark._y = field._y + field._height / 2;
   mark._visible = true;
};

// the arrow goes after the game's icons, the quest sign and the junk sign
Equipment.afterIcons = function(row, field, entry, state)
{
   return Equipment.questEnd(row, field, entry, state) + (Equipment.junkShown(entry) ? Equipment.JUNK_SIGN + Equipment.ICON_GAP : 0);
};

// Where the name of a row ends with the signs and the arrow after it, in the panel's units. 0 for a row with no clip
// in sight, the menu of a row stands past it
Equipment.nameEnd = function(entry)
{
   var list = Equipment.menu.inventoryLists.itemList;
   var row = entry != undefined && entry.clipIndex != undefined ? list.getClipByIndex(entry.clipIndex) : undefined;
   var field = row != undefined && row.itemIndex == entry.itemIndex ? row.equipmentNameField : undefined;
   var mark;
   var point;
   if(field == undefined)
   {
      return 0;
   }
   mark = row.equipmentMark;
   point = {x:mark != undefined && mark._visible ? mark._x + mark._width : Equipment.afterIcons(row, field, entry, list.listState), y:0};
   row.localToGlobal(point);
   return Equipment.number(Equipment.toPanel(point).x);
};

// the junk sign goes after the game's icons and the quest sign
Equipment.questEnd = function(row, field, entry, state)
{
   return Equipment.iconsEnd(row, field, entry, state) + (Equipment.questShown(entry) ? Equipment.QUEST_SIGN + Equipment.ICON_GAP : 0);
};

// the row puts its own icons after the name one by one
Equipment.iconsEnd = function(row, field, entry, state)
{
   var shown = 0;
   var flags = [entry.bestInClass, entry.favorite, entry.isPoisoned, (entry.isStolen == true || entry.isStealing == true) && state.showStolenIcon == true, entry.isEnchanted, entry.isRead];
   // a row clip of a skin with no best icon has no width to step by, the marks went to x = NaN
   var step = row.bestIcon._width > 0 ? row.bestIcon._width * Equipment.ICON_STEP : field._height;
   var i = 0;
   while(i < flags.length)
   {
      if(flags[i] == true)
      {
         shown++;
      }
      i++;
   }
   return Math.max(field._x + field._width + Equipment.ICON_GAP + shown * step, Equipment.number(Equipment.othersEnd(row, field)) + Equipment.ICON_GAP);
};

// pictures and the height of rows are for lists of things, spells and recipes keep their own signs
Equipment.itemRows = function()
{
   return Equipment.kind == "inventory" || Equipment.kind == "container" || Equipment.kind == "barter";
};

Equipment.rowShare = function()
{
   var share = Equipment.number(Equipment.settings.rowHeight) / 100;
   return share > 1 ? share : 1;
};

// SkyUI makes a row as high as its tallest column, that's the icon. The icon grows until the row is the height asked
// for, the other columns go down by half of that to stay in the row's middle. Every size goes from what the skin set,
// the height can change while the menu is up
Equipment.growRows = function(columns)
{
   var share = Equipment.rowShare();
   var grown = 0;
   var column;
   var more;
   var key;
   Equipment.rowColumns = columns;
   if(!Equipment.itemRows() || share == 1 && !Equipment.rowsGrown)
   {
      return undefined;
   }
   for(key in columns)
   {
      column = columns[key];
      if(column.type == Equipment.ITEM_COLUMN && column.icon != undefined)
      {
         column.equipmentSize = column.equipmentSize != undefined ? column.equipmentSize : column.icon.size;
         more = (column.equipmentSize + Equipment.number(column.border[2]) + Equipment.number(column.border[3])) * (share - 1);
         grown = Math.max(grown, more);
         column.icon.size = column.equipmentSize + more;
      }
   }
   for(key in columns)
   {
      column = columns[key];
      if(column.type != Equipment.ITEM_COLUMN)
      {
         column.equipmentBorder = column.equipmentBorder != undefined ? column.equipmentBorder : (column.border != undefined ? column.border : [0, 0, 0, 0]);
         column.border = [column.equipmentBorder[0], column.equipmentBorder[1], column.equipmentBorder[2] + grown / 2, column.equipmentBorder[3]];
      }
   }
   Equipment.rowsGrown = true;
   // a menu that read its settings before the panel came has its layout made already
   Equipment.menu.inventoryLists.itemList.layout.refresh();
};

// the height set on the sheet in the menu
Equipment.rowHeightChanged = function()
{
   Equipment.growRows(Equipment.rowColumns);
   Equipment.fitRows(Equipment.menu.inventoryLists.itemList);
};

// SkyUI sizes the signs after a name by the row's height, they stay the size they have in a row of the usual height
Equipment.keepSigns = function(row, state)
{
   if(!Equipment.rowsGrown)
   {
      return undefined;
   }
   var high = state.list.layout.entryHeight;
   var size = high / Equipment.rowShare() * Equipment.SIGN_SHARE;
   var sign;
   var i = 0;
   while(i < Equipment.ROW_SIGNS.length)
   {
      sign = row[Equipment.ROW_SIGNS[i]];
      sign._height = sign._width = size;
      sign._y = (high - size) / 2;
      i++;
   }
};

// a chest or a shop has no window that follows the list, the rows watch it themselves
Equipment.watchRows = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   list.equipmentUpdateList = list.UpdateList;
   list.UpdateList = function()
   {
      this.equipmentUpdateList();
      Equipment.showRowModels();
   };
};

// the switch on the sheet, the rows go back to their signs at once or ask for their pictures again
Equipment.rowPicturesChanged = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   var row;
   var i = 0;
   if(!Equipment.settings.rowModels)
   {
      clearInterval(Equipment.rowsTicking);
      Equipment.rowsTicking = undefined;
      while(i < list._listIndex)
      {
         row = list.getClipByIndex(i);
         row.itemIcon._alpha = 100;
         Equipment.showRowPicture(row, "", false);
         i++;
      }
   }
   Equipment.rowsShown = Equipment.rowsWhole = undefined;
   list.UpdateList();
};

// Rows in sight show a picture of their item in place of the icon. The plugin makes a missing one once the list has
// stood still for a moment, a list going by reads nothing, and a row keeps its flat icon until the picture is there
Equipment.showRowModels = function()
{
   var plugin = Equipment.plugin();
   var list = Equipment.menu.inventoryLists.itemList;
   if(plugin == undefined || plugin.WantPictures == undefined || !Equipment.settings.rowModels || !Equipment.itemRows())
   {
      return undefined;
   }
   var forms = [];
   var row;
   var i = 0;
   while(i < list._listIndex)
   {
      row = list.getClipByIndex(i);
      if(row != undefined && row._visible && list.entryList[row.itemIndex] != undefined)
      {
         forms.push(list.entryList[row.itemIndex].formId);
      }
      i++;
   }
   var shown = forms.join(",");
   if(shown != Equipment.rowsShown)
   {
      Equipment.rowsShown = shown;
      plugin.WantPictures(forms);
      Equipment.rowsMovedAt = getTimer();
      Equipment.tellWholeList(plugin, list);
      if(Equipment.rowsTicking == undefined)
      {
         Equipment.rowsTicking = setInterval(Equipment.tickRows, Equipment.ROWS_TICK);
      }
   }
   Equipment.paintRows();
};

// the list holds every category, its rows only change between them, so this runs when the items themselves change
Equipment.tellWholeList = function(plugin, list)
{
   var entries = list.entryList;
   if(entries.length == Equipment.rowsWhole)
   {
      return undefined;
   }
   Equipment.rowsWhole = entries.length;
   var forms = [];
   var i = 0;
   while(i < entries.length)
   {
      if(entries[i].formId != undefined)
      {
         forms.push(entries[i].formId);
      }
      i++;
   }
   plugin.AheadPictures(forms);
};

Equipment.tickRows = function()
{
   var plugin = Equipment.plugin();
   var now = getTimer();
   if(_root._xmouse != Equipment.rowsMouseX || _root._ymouse != Equipment.rowsMouseY)
   {
      Equipment.rowsMouseX = _root._xmouse;
      Equipment.rowsMouseY = _root._ymouse;
      Equipment.rowsMouseAt = now;
   }
   if(now - Equipment.rowsMovedAt < Equipment.ROWS_QUIET)
   {
      return undefined;
   }
   var waiting = plugin.GrowPictures(now - Equipment.rowsMovedAt >= Equipment.ROWS_IDLE && now - Equipment.rowsMouseAt >= Equipment.ROWS_IDLE);
   Equipment.paintRows();
   if(!waiting)
   {
      clearInterval(Equipment.rowsTicking);
      Equipment.rowsTicking = undefined;
   }
};

Equipment.paintRows = function()
{
   var plugin = Equipment.plugin();
   var list = Equipment.menu.inventoryLists.itemList;
   var entry;
   var row;
   var url;
   var i = 0;
   while(i < list._listIndex)
   {
      row = list.getClipByIndex(i);
      entry = list.entryList[row.itemIndex];
      url = entry != undefined ? plugin.PictureUrl(entry.formId) : "";
      // the tile stands on every row from the start, a picture coming later changes nothing around it
      row.itemIcon._alpha = url != "" ? 0 : 100;
      Equipment.showRowPicture(row, url, entry != undefined);
      i++;
   }
};

// a lighter square under the picture, the dark line of the picture keeps a white thing apart from it
Equipment.showRowPicture = function(row, url, inUse)
{
   var tile = row.equipmentTile;
   var holder = row.equipmentPicture;
   if(tile == undefined)
   {
      tile = row.createEmptyMovieClip("equipmentTile", row.getNextHighestDepth());
      holder = row.createEmptyMovieClip("equipmentPicture", row.getNextHighestDepth());
      holder.hitTestDisable = true;
      tile.hitTestDisable = true;
      // the dot of a new item stays over both
      if(row.equipmentNew != undefined)
      {
         row.equipmentNew.swapDepths(row.getNextHighestDepth());
      }
   }
   tile._visible = inUse;
   holder._visible = url != "";
   if(!inUse)
   {
      holder.url = undefined;
      return undefined;
   }
   var box = row.itemIcon.getBounds(row);
   var top = {x:0, y:0};
   var bottom = {x:0, y:100};
   row.localToGlobal(top);
   row.localToGlobal(bottom);
   var unit = Stage.visibleRect.height * 100 / (bottom.y - top.y);
   // a skin's rows can be lower than the share asks, a tile higher than its row lay over the next one
   var size = Math.min(Equipment.ROW_TILE_SIZE * Equipment.rowShare() * unit, Equipment.menu.inventoryLists.itemList.layout.entryHeight - Equipment.ROW_TILE_GAP);
   var half = size / 2;
   holder.x = (box.xMin + box.xMax) / 2;
   holder.y = (box.yMin + box.yMax) / 2;
   holder.size = size;
   tile.clear();
   tile.lineStyle(1, Equipment.GOLD, 45);
   tile.beginFill(Equipment.PARCHMENT, Equipment.ROW_TILE_ALPHA);
   tile.moveTo(holder.x - half, holder.y - half);
   tile.lineTo(holder.x + half, holder.y - half);
   tile.lineTo(holder.x + half, holder.y + half);
   tile.lineTo(holder.x - half, holder.y + half);
   tile.lineTo(holder.x - half, holder.y - half);
   tile.endFill();
   if(url == "")
   {
      holder.url = undefined;
   }
   else if(holder.url != url)
   {
      // the picture a row held stays until the next one is up, a blank row for a frame is what makes scrolling blink
      var fresh = holder.art == undefined || holder.url == undefined;
      holder.url = url;
      holder.depth = Equipment.number(holder.depth) + 1;
      var coming = holder.createEmptyMovieClip("art" + holder.depth, holder.depth);
      coming._alpha = 0;
      var loader = new MovieClipLoader();
      loader.addListener({onLoadInit:function(art)
      {
         art.loaded = true;
         var place = art._parent;
         if(place.url == url)
         {
            place.art.removeMovieClip();
            place.art = art;
            Equipment.fitRowPicture(place);
            Equipment.showArt(art, fresh);
         }
         else
         {
            art.removeMovieClip();
         }
      }});
      loader.loadClip(url, coming);
   }
   else if(holder.art.loaded)
   {
      Equipment.fitRowPicture(holder);
   }
};

// a picture that takes the place of a flat icon comes in softly, one that follows another on a list going by at once
Equipment.showArt = function(art, soft)
{
   if(!soft)
   {
      art._alpha = 100;
      return undefined;
   }
   art.onEnterFrame = function()
   {
      this._alpha += Equipment.ROW_FADE_STEP;
      if(this._alpha >= 100)
      {
         this._alpha = 100;
         delete this.onEnterFrame;
      }
   };
};

Equipment.fitRowPicture = function(holder)
{
   holder.art._width = holder.art._height = holder.size;
   holder.art._x = holder.x - holder.size / 2;
   holder.art._y = holder.y - holder.size / 2;
};

// for tests, what the rows in sight show
Equipment.rowPicturesReport = function(note)
{
   var list = Equipment.menu.inventoryLists.itemList;
   var told = [];
   var row;
   var i = 0;
   while(i < list._listIndex)
   {
      row = list.getClipByIndex(i);
      told.push(list.entryList[row.itemIndex].text + "=" + (row.equipmentPicture.url == undefined ? "icon" : (row.equipmentPicture.art.loaded ? Math.round(row.equipmentPicture.art._width) : "loading")));
      i++;
   }
   skse.Log("PANELTEST row pictures " + note + ": " + told.join(", "));
};

// the parts of SkyUI's row, the marks go after the icons of these it shows
Equipment.ROW_PARTS = {background:true, selectIndicator:true, itemIcon:true, equipIcon:true, bestIcon:true, favoriteIcon:true, poisonIcon:true, stolenIcon:true, enchIcon:true, readIcon:true};

// Other mods put signs of their own after the name (PNG Icon Injector's status icons, SkyUI's icons drawn anew by it)
// and the marks lay over them. Where the last of them ends: a part of the row that isn't SkyUI's or ours, in sight,
// from the name's end to the end of its column. A skin's bar across the row starts before the name or runs past
// half the column, it's left out. So is an icon that hides by a frame of its own the way SkyUI's do, it keeps its
// size while hidden (SkyUI AIO Survival's enchantment icons stand on every row)
Equipment.othersEnd = function(row, field)
{
   var list = Equipment.menu.inventoryLists.itemList;
   var end = list != undefined && list.layout != undefined ? Equipment.columnEnd(field) : undefined;
   var from = field._x + field._width - 2;
   var last;
   var part;
   var box;
   for(var name in row)
   {
      part = row[name];
      if((part instanceof MovieClip && !(part._totalframes > 1) || part instanceof TextField && part.text != "") && part._parent == row && part._visible && part._alpha > 0 && Equipment.ROW_PARTS[name] != true && name.indexOf("equipment") != 0 && name.indexOf("textField") != 0)
      {
         box = Equipment.partBox(part, row);
         if(box.xMax > box.xMin && box.xMin >= from && end != undefined && box.xMax <= end && box.xMax - box.xMin < (end - field._x) / 2 && (last == undefined || box.xMax > last))
         {
            last = box.xMax;
         }
      }
   }
   return last;
};

// for tests, what stands after the name in every row in sight, each part with its span in the row's units
Equipment.rowSignsReport = function(note)
{
   var list = Equipment.menu.inventoryLists.itemList;
   var entries = list.entryList;
   var row;
   var parts;
   var box;
   var i = 0;
   skse.Log("PANELTEST row signs " + note + ": our formatName on top " + (_global.InventoryListEntry.prototype.formatName == Equipment.rowFormat) + ", under it " + typeof _global.InventoryListEntry.prototype.equipmentFormatName);
   while(i < entries.length)
   {
      row = list.getClipByIndex(i);
      if(i < list._listIndex && row != undefined && row._visible && entries[row.itemIndex] != undefined)
      {
         parts = [];
         for(var name in row)
         {
            if((row[name] instanceof MovieClip || row[name] instanceof TextField) && row[name]._parent == row && row[name]._visible)
            {
               box = Equipment.partBox(row[name], row);
               parts.push(name + " " + Math.round(box.xMin) + "-" + Math.round(box.xMax) + " y " + Math.round(box.yMin) + "-" + Math.round(box.yMax) + (row[name]._totalframes > 1 ? " frames " + row[name]._totalframes : "") + (name == "equipmentMark" ? " '" + row[name].amount.text + "'" : ""));
            }
         }
         skse.Log("PANELTEST row signs " + note + " " + entries[row.itemIndex].text + " at " + Math.round(row._y) + ": " + parts.join(", "));
      }
      i++;
   }
};

Equipment.createMark = function(row)
{
   var mark = row.createEmptyMovieClip("equipmentMark", row.getNextHighestDepth());
   mark.createEmptyMovieClip("arrow", 1);
   mark.createTextField("amount", 2, Equipment.ARROW_WIDTH + 3, -10, 60, 20);
   mark.amount.selectable = false;
   mark.amount.setNewTextFormat(new TextFormat("$EverywhereMediumFont", 13, Equipment.BETTER));
   return mark;
};

Equipment.drawArrow = function(arrow, up, color)
{
   var tip = up ? -Equipment.ARROW_HEIGHT / 2 : Equipment.ARROW_HEIGHT / 2;
   arrow.clear();
   arrow.beginFill(color, 100);
   arrow.moveTo(0, -tip);
   arrow.lineTo(Equipment.ARROW_WIDTH / 2, tip);
   arrow.lineTo(Equipment.ARROW_WIDTH, -tip);
   arrow.lineTo(0, -tip);
   arrow.endFill();
};

// A row of something wearable that isn't worn shows the slot it would go to. The badge sits where a
// worn row has its mark, in the first column of the list
Equipment.showBadge = function(row, entry, state)
{
   var slot = entry.equipState > 0 || !Equipment.settings.badges ? undefined : Equipment.slotOf(entry);
   var place = Equipment.equipColumn(state);
   var badge = row.equipmentBadge;
   if(slot == undefined || place == undefined)
   {
      badge._visible = false;
      return undefined;
   }
   if(badge == undefined)
   {
      badge = row.createEmptyMovieClip("equipmentBadge", row.getNextHighestDepth());
   }
   var size = Math.min(place.width, place.height);
   badge._x = place.x;
   badge._y = place.y;
   badge._visible = true;
   if(badge.slot == slot && badge.size == size)
   {
      return undefined;
   }
   badge.slot = slot;
   badge.size = size;
   badge.clear();
   badge.lineStyle(1, Equipment.inkOf("edge"), 30, true);
   badge.beginFill(Equipment.paper ? Equipment.WHITE : 0, Equipment.paper ? 18 : 30);
   Equipment.roundBox(badge, 0, 0, size, size, 3);
   badge.endFill();
   Equipment.drawIcon(badge, slot.icon, Equipment.BADGE_INSET, Equipment.BADGE_INSET, size - 2 * Equipment.BADGE_INSET, Equipment.paper ? Equipment.inkOf("chip") : Equipment.PARCHMENT, 75);
};

Equipment.equipColumn = function(state)
{
   var columns = state.list.layout.columnLayoutData;
   var i = 0;
   while(i < columns.length)
   {
      if(columns[i].type == Equipment.EQUIP_COLUMN)
      {
         return columns[i];
      }
      i++;
   }
   return undefined;
};

// for tests, the first rows of the list as it stands now, with what the comparison and the sorting made
// of each. The lines go to the log of the script extender
Equipment.rowsReport = function(count)
{
   var list = Equipment.menu.inventoryLists.itemList;
   var rows = list.listEnumeration;
   var entry;
   var i = 0;
   skse.Log("EquipmentPanel rows: " + rows.size() + " rows, column " + list.layout.activeColumnIndex + " state " + list.layout.activeColumnState);
   while(i < rows.size() && i < count)
   {
      entry = rows.at(i);
      skse.Log("EquipmentPanel row " + i + ": " + entry.text + " x" + entry.count + ", type " + entry.formType + " sub " + entry.subType + " (" + entry.subTypeDisplay + ") class " + entry.weightClass + ", icon " + entry.iconLabel + ", slots " + entry.partMask + ", worn " + entry.equipState + ", armor " + entry.infoArmor + ", damage " + entry.infoDamage + ", difference " + entry.equipmentDifference + ", weight " + entry.infoWeight + ", stack " + entry.infoStackWeight + ", added " + entry.equipmentAdded + ", new " + Equipment.isNew(entry) + ", junk " + entry.equipmentJunk + ", quest " + entry.equipmentQuest + ", stolen " + entry.equipmentStolen + " (" + entry.isStolen + "), carried " + entry.equipmentCarried + ", from " + entry.equipmentOrigin + ", weight colour " + entry.equipmentWeightColor);
      i++;
   }
   Equipment.rowsReported = rows.size();
};

// for tests, how long the list lays its rows out the way SkyUI does, with the panel's marks of rows and with
// all the panel's work. A list that scrolls smoothly lays them out every 16 ms while it moves. Three rounds in turn,
// the shortest of each counts, a stall of the game in one round would read as the panel's cost
Equipment.listUpdateReport = function(times)
{
   var plugin = Equipment.plugin();
   var list = Equipment.menu.inventoryLists.itemList;
   var row = _global.InventoryListEntry.prototype;
   var ours = row.formatName;
   var count = Number(times);
   var least = [];
   var told = [];
   var took;
   var round = 0;
   var way;
   if(plugin == undefined || plugin.Clock == undefined || list.equipmentUpdateList == undefined)
   {
      return undefined;
   }
   while(round < 3)
   {
      way = 0;
      while(way < 3)
      {
         row.formatName = way == 0 ? row.equipmentFormatName : ours;
         took = Equipment.timeLayouts(plugin, list, count, way == 2);
         least[way] = least[way] == undefined ? took : Math.min(least[way], took);
         told.push(Math.round(took));
         way++;
      }
      round++;
   }
   row.formatName = ours;
   skse.Log("PANELTEST list laid out " + count + " times with " + list._listIndex + " rows: as SkyUI " + Math.round(least[0]) + " ms, with the marks of rows " + Math.round(least[1]) + " ms, with all the panel " + Math.round(least[2]) + " ms (rounds " + told.join("/") + ")");
};

Equipment.timeLayouts = function(plugin, list, count, all)
{
   var start = plugin.Clock();
   var i = 0;
   while(i < count)
   {
      if(all)
      {
         list.UpdateList();
      }
      else
      {
         list.equipmentUpdateList();
      }
      i++;
   }
   return plugin.Clock() - start;
};
