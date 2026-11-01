Equipment.STATS_LINE = 18;
Equipment.STOLEN_TEXT = 14;
Equipment.STOLEN_GAP = 4;
Equipment.BODY_SLOTS_TEXT = 12;
Equipment.BODY_SLOTS_COLOR = 0x9C978B;
Equipment.FIRST_BODY_SLOT = 30;

// Base timings of the game's own attack animations at speed 1, read from its behavior files:
// a one handed swing lands 0.70 s after the press and the next one may start at 1.20 s,
// a two handed one lands at 0.80 s and chains at 1.13 s. A bow is drawn full in about a second and
// takes 0.8 s to loose and nock again, a crossbow about 2.5 s a shot. The weapon's speed and the player's
// attack speed divide them. Animation mods change these, so the numbers are a guide
Equipment.SWING = {oneHanded:{hit:0.7, cycle:1.2}, twoHanded:{hit:0.8, cycle:1.13}, bow:{hit:1.0, cycle:1.8}, crossbow:{hit:1.0, cycle:2.5}};

// the numbers block lives under the card, two columns of names and values
Equipment.buildStats = function(window)
{
   window.createTextField("statNames", 2, 0, 0, 10, 10);
   window.createTextField("statValues", 3, 0, 0, 10, 10);
   Equipment.styleText(window.statNames, Equipment.STATS_TEXT, "left", Equipment.inkOf("name"));
   Equipment.styleText(window.statValues, Equipment.STATS_TEXT, "right", Equipment.inkOf("value"));
   window.statNames.multiline = window.statValues.multiline = true;
   window.statNames.wordWrap = window.statValues.wordWrap = false;
   window.statValues.html = true;
   window.statLines = [];
   // the numbers in columns, a field of their own over the list's two
   window.createTextField("statGrid", 6, 0, 0, 10, 10);
   Equipment.styleText(window.statGrid, Equipment.STATS_TEXT, "left", Equipment.inkOf("value"));
   window.statGrid.multiline = true;
   window.statGrid.wordWrap = false;
   window.statGrid.html = true;
   window.statGrid._visible = false;

   // a quiet line of the game's body slots under the numbers, it keeps clear of the lens
   window.createTextField("bodySlots", 4, 0, 0, 10, 10);
   Equipment.styleText(window.bodySlots, Equipment.BODY_SLOTS_TEXT, "left", Equipment.inkOf("quiet"));
   window.bodySlots.multiline = window.bodySlots.wordWrap = true;
   window.bodySlots.autoSize = "left";
   window.bodySlots._width = window.wide - 2 * Equipment.STATS_PAD - Equipment.LENS_SIZE;
   window.bodySlots._visible = false;

   // the stolen note of the game's card, as a line of its own over the quiet ones
   window.createTextField("stolen", 5, 0, 0, 10, 10);
   Equipment.styleText(window.stolen, Equipment.STOLEN_TEXT, "left", Equipment.inkOf("stolen"));
   window.stolen.autoSize = "left";
   window.stolen._visible = false;

   // a line of the menu's own under the numbers, what a crafting station asks for a recipe in its own colours
   window.createTextField("extra", 8, 0, 0, 10, 10);
   Equipment.styleText(window.extra, Equipment.BODY_SLOTS_TEXT, "left", Equipment.inkOf("value"));
   window.extra.multiline = window.extra.wordWrap = true;
   window.extra.html = true;
   window.extra.autoSize = "left";
   window.extra._visible = false;
};

Equipment.extraHeight = function()
{
   var line = Equipment.window.extra;
   return line != undefined && line._visible ? line._height + Equipment.STOLEN_GAP : 0;
};

Equipment.statsHeight = function()
{
   var window = Equipment.window;
   var lines = window.statLines.length;
   return lines == 0 ? 0 : Equipment.statsTextHigh(window) + 2 * Equipment.STATS_PAD - 6;
};

// the numbers block and the small lines at the sizes the player set on the Item window page
Equipment.statsText = function()
{
   return Math.round(Equipment.STATS_TEXT * Equipment.textShare("numbers"));
};

Equipment.statsLine = function()
{
   return Math.round(Equipment.STATS_LINE * Equipment.textShare("numbers"));
};

// the lines as tall as their letters are, a font with taller lines (a language's own) cut the last one off
Equipment.statsTextHigh = function(window)
{
   var rows = window.statsInColumns == true ? Equipment.number(window.statRows) : window.statLines.length;
   return Math.max(rows * Equipment.statsLine(), Equipment.number(window.statsHigh));
};

// the column of values as wide as its widest value, half the window at the least. Numbers in columns have none
Equipment.valuesWide = function(window)
{
   return window.statsInColumns == true ? 0 : Math.max(window.wide / 2 - Equipment.STATS_PAD, Equipment.number(window.valuesWide));
};

Equipment.styleStats = function(window)
{
   var quiet = Equipment.textShare("quiet");
   Equipment.styleText(window.statNames, Equipment.statsText(), "left", Equipment.inkOf("name"));
   Equipment.styleText(window.statValues, Equipment.statsText(), "right", Equipment.inkOf("value"));
   Equipment.styleText(window.statGrid, Equipment.statsText(), "left", Equipment.inkOf("value"));
   Equipment.styleText(window.bodySlots, Math.round(Equipment.BODY_SLOTS_TEXT * quiet), "left", Equipment.inkOf("quiet"));
   Equipment.styleText(window.stolen, Math.round(Equipment.STOLEN_TEXT * quiet), "left", Equipment.inkOf("stolen"));
};

Equipment.stolenHeight = function()
{
   var line = Equipment.window.stolen;
   return line != undefined && line._visible ? line._height + Equipment.STOLEN_GAP : 0;
};

// The game marks a whole row stolen, the plugin counts the copies of it that belong to someone else. Without that
// count the game's own mark still says it. With stolen copies in rows of their own a stolen row is all stolen, the
// count is only for a row that still mixes them, a merchant's say
Equipment.stolenLine = function(entry)
{
   var count = Math.max(Equipment.number(entry.count), 1);
   var stolen = Math.min(Equipment.number(entry.equipmentStolen), count);
   if(stolen <= 0)
   {
      return entry.isStolen == true ? Equipment.say("Stolen") : "";
   }
   return stolen == count ? Equipment.say("Stolen") : Equipment.say("Stolen: #1 of #2", stolen, count);
};

// whether a row holds stolen copies, two rows of one item with the same name differ by it
Equipment.stolenRow = function(entry)
{
   return Equipment.number(entry.equipmentStolen) > 0 || entry.isStolen == true;
};

// what finds a row again after the menu listed anew, the rows are new objects then
Equipment.rowKey = function(entry)
{
   return {formId:entry.formId, text:entry.text, stolen:Equipment.stolenRow(entry)};
};

Equipment.isRow = function(entry, key)
{
   return entry.formId == key.formId && entry.text == key.text && Equipment.stolenRow(entry) == key.stolen;
};

// The numbers stand in columns of two, each name right beside its value: damage a second and a minute, swing and reach,
// stagger and crit damage, for armor what a piece stops and the whole set, then effective health and armor per weight.
// A list of names with their values at the far end left a wide gap in each line and took a line each, a long
// description above had no room left. A window too narrow for the columns even at the smallest sizes keeps that list
Equipment.STATS_GRID = [["dps", "dpm"], ["swing", "reach"], ["stagger", "crit"], ["stops", "set"], ["health", "perWeight"]];
Equipment.STATS_CELL_GAP = 9;
Equipment.STATS_INNER_GAP = 4;
// a change in brackets beside a value is a size under the names, it only tells better or worse
Equipment.STATS_CHANGE = 0.8;
// names and values larger than the list's numbers, a value a size over its name and its change in brackets, as the
// card's own DAMAGE and WEIGHT stand by their numbers. Changes in brackets against the worn weapon make the columns
// wider, they take the next sizes down before the list comes back
Equipment.STATS_SIZES = [{name:1.1, value:1.3}, {name:1, value:1.15}, {name:0.9, value:1}];
Equipment.statsSize = Equipment.STATS_SIZES[0];

Equipment.statsColumns = function(lines)
{
   var columns = [];
   var column;
   var group;
   var g = 0;
   var k;
   var i;
   while(g < Equipment.STATS_GRID.length)
   {
      group = Equipment.STATS_GRID[g];
      column = [];
      k = 0;
      while(k < group.length)
      {
         i = 0;
         while(i < lines.length && lines[i].key != group[k])
         {
            i++;
         }
         if(i < lines.length)
         {
            column.push(lines[i]);
         }
         k++;
      }
      if(column.length > 0)
      {
         columns.push(column);
      }
      g++;
   }
   return columns;
};

// for tests, how the columns came out for the window's row, every size tried with its width and the room
Equipment.gridReport = function(note)
{
   skse.Log("PANELTEST grid " + note + ": columns " + (Equipment.window.statsInColumns == true) + ", sizes tried " + Equipment.gridTried + ", window " + Math.round(Equipment.window.wide));
};

Equipment.statName = function(line)
{
   return "<font size='" + Math.round(Equipment.statsText() * Equipment.statsSize.name) + "' color='" + Equipment.hex(Equipment.inkOf("name")) + "'>" + Equipment.htmlSafe(String(line[0])) + "</font>";
};

Equipment.statValue = function(line)
{
   return "<font size='" + Math.round(Equipment.statsText() * Equipment.statsSize.value) + "'>" + Equipment.valueHtml(line[1], line[2], Math.round(Equipment.statsText() * Equipment.STATS_CHANGE)) + "</font>";
};

// the face of the panel's letters with the sizes the html gave each part left as they are
Equipment.lettersFace = function(align)
{
   var format = new TextFormat("$EverywhereMediumFont");
   format.align = align;
   return format;
};

// The columns in a field of their own, each column as wide as its widest name and value and every value of a
// column at one place, so Swing and Reach start their values together. Spread over the window when each column
// fits its share, close together when only that fits, at the next sizes down when not even that, false when none
// fits and the list stays
Equipment.layStatsColumns = function(window, columns)
{
   var i = 0;
   Equipment.gridTried = undefined;
   while(i < Equipment.STATS_SIZES.length)
   {
      Equipment.statsSize = Equipment.STATS_SIZES[i];
      if(Equipment.layStatsAt(window, columns))
      {
         return true;
      }
      i++;
   }
   Equipment.statsSize = Equipment.STATS_SIZES[0];
   return false;
};

Equipment.layStatsAt = function(window, columns)
{
   var field = window.statGrid;
   var room = window.wide - 2 * Equipment.STATS_PAD;
   var gap = Equipment.STATS_CELL_GAP;
   var inner = Equipment.STATS_INNER_GAP;
   var names = [];
   var values = [];
   var starts = [];
   var rows = 0;
   var total = 0;
   var spread = true;
   var stops = [];
   var lines = [];
   var cells;
   var format;
   var wide;
   var c = 0;
   var r;
   var measure = function(html)
   {
      field.htmlText = html;
      field.setTextFormat(Equipment.lettersFace("left"));
      return field.textWidth;
   };
   while(c < columns.length)
   {
      names[c] = 0;
      values[c] = 0;
      r = 0;
      while(r < columns[c].length)
      {
         names[c] = Math.max(names[c], measure(Equipment.statName(columns[c][r])));
         values[c] = Math.max(values[c], measure(Equipment.statValue(columns[c][r])));
         r++;
      }
      wide = names[c] + inner + values[c];
      rows = Math.max(rows, columns[c].length);
      total += wide + (c > 0 ? gap : 0);
      spread = spread && wide <= room / columns.length - (c < columns.length - 1 ? gap : 0);
      c++;
   }
   Equipment.gridTried = (Equipment.gridTried != undefined ? Equipment.gridTried + "; " : "") + Equipment.statsSize.name + "/" + Equipment.statsSize.value + " needs " + Math.round(total) + " of " + Math.round(room - 4);
   if(columns.length < 2 || total > room - 4)
   {
      return false;
   }
   c = 0;
   while(c < columns.length)
   {
      starts[c] = Math.round(spread ? c * room / columns.length : c > 0 ? starts[c - 1] + names[c - 1] + inner + values[c - 1] + gap : 0);
      if(c > 0)
      {
         stops.push(starts[c]);
      }
      stops.push(Math.round(starts[c] + names[c] + inner));
      c++;
   }
   r = 0;
   while(r < rows)
   {
      cells = [];
      c = 0;
      while(c < columns.length)
      {
         cells.push(columns[c][r] != undefined ? Equipment.statName(columns[c][r]) : "");
         cells.push(columns[c][r] != undefined ? Equipment.statValue(columns[c][r]) : "");
         c++;
      }
      lines.push(cells.join("	"));
      r++;
   }
   field.htmlText = lines.join("<br>");
   format = Equipment.lettersFace("left");
   format.tabStops = stops;
   field.setTextFormat(format);
   window.statRows = rows;
   return true;
};

Equipment.fillStats = function(wide)
{
   var window = Equipment.window;
   // while the card shows the list of a recharge its words are the list's, the numbers of the item step out
   var entry = Equipment.chargeListUp() ? undefined : Equipment.windowEntry();
   var lines = Equipment.settings.stats && entry != undefined ? Equipment.statsOf(entry) : [];
   var names = [];
   var values = [];
   var room = window.wide / 2 - Equipment.STATS_PAD - 4;
   var measure = function(words)
   {
      window.statNames.text = words;
      return window.statNames.textWidth;
   };
   var i = 0;
   window.statLines = lines;
   Equipment.styleStats(window);
   window.statsInColumns = lines.length > 0 && Equipment.layStatsColumns(window, Equipment.statsColumns(lines));
   window.statGrid._visible = window.statsInColumns;
   if(window.statsInColumns)
   {
      window.valuesWide = 0;
      window.statsHigh = window.statGrid.textHeight;
      window.statNames._visible = window.statValues._visible = false;
      Equipment.fillSmallLines(window, entry);
      return undefined;
   }
   window.statRows = lines.length;
   // the values first: a value never gets cut, the names take the room it leaves
   while(i < lines.length)
   {
      values.push(Equipment.valueHtml(lines[i][1], lines[i][2]));
      i++;
   }
   window.statValues.htmlText = values.join("<br>");
   window.statValues.setTextFormat(Equipment.lettersOnly(Equipment.statsText(), "right"));
   window.valuesWide = lines.length > 0 ? window.statValues.textWidth + 6 : 0;
   room = window.wide - 2 * Equipment.STATS_PAD - Equipment.valuesWide(window) - 4;
   i = 0;
   while(i < lines.length)
   {
      names.push(Equipment.cutToFit(lines[i][0], room, measure));
      i++;
   }
   window.statNames.text = names.join("\n");
   window.statsHigh = lines.length > 0 ? window.statNames.textHeight : 0;
   window.statNames._visible = window.statValues._visible = lines.length > 0;
   Equipment.fillSmallLines(window, entry);
};

// the stolen note and the quiet lines under the numbers
Equipment.fillSmallLines = function(window, entry)
{
   window.stolen.text = entry != undefined && Equipment.lineShown("stolen") ? Equipment.stolenLine(entry) : "";
   window.stolen.textColor = Equipment.inkOf("stolen");
   window.stolen._visible = window.stolen.text != "";
   window.bodySlots.text = entry != undefined ? Equipment.quietLines(entry).join("\n") : "";
   window.bodySlots._visible = window.bodySlots.text != "";
};

// A value of the numbers block as html with its change in brackets after it in the ink of better or worse, or the
// value in that ink when the change has no words of its own. small is the size of the brackets, none keeps the field's
Equipment.valueHtml = function(value, change, small)
{
   var words = Equipment.htmlSafe(String(value));
   var plain = "<font color='" + Equipment.hex(Equipment.inkOf("value")) + "'>" + words + "</font>";
   if(change == undefined)
   {
      return plain;
   }
   if(change.text == undefined)
   {
      return "<font color='" + Equipment.hex(Equipment.inkOf(change.role)) + "'>" + words + "</font>";
   }
   return plain + " <font " + (small != undefined ? "size='" + small + "' " : "") + "color='" + Equipment.hex(Equipment.inkOf(change.role)) + "'>" + Equipment.htmlSafe(Equipment.bracketed(change)) + "</font>";
};

Equipment.bracketed = function(change)
{
   return "(" + change.text + ")";
};

// Words cut short with "..." till they're no wider than wide as measure reads them. A long arrow's name in a line
// pushed the numbers out of sight. The share of the letters that fits is the first guess, a guess too long is cut by
// halves, so a mod's name of 500 letters wide and narrow mixed costs only a few measures
Equipment.cutToFit = function(words, wide, measure)
{
   var whole = String(words);
   var now = measure(whole);
   var keep;
   var low;
   var high;
   var middle;
   if(now <= wide)
   {
      return whole;
   }
   keep = Math.min(whole.length - 1, Math.ceil(whole.length * wide / now));
   if(!(keep > 1) || measure(whole.substr(0, keep) + "...") <= wide)
   {
      return whole.substr(0, keep) + "...";
   }
   low = 1;
   high = keep - 1;
   while(low < high)
   {
      middle = Math.ceil((low + high) / 2);
      if(measure(whole.substr(0, middle) + "...") <= wide)
      {
         low = middle;
      }
      else
      {
         high = middle - 1;
      }
   }
   return whole.substr(0, low) + "...";
};

// The panel's letters with no colour, html text loses the field's own font and this brings it back over the inks
Equipment.lettersOnly = function(size, align)
{
   var format = new TextFormat("$EverywhereMediumFont", size);
   format.align = align;
   return format;
};

// The quiet lines under the numbers: what a quest wants with the item, its body slots, how many the player has
// already when it lies in a chest or a shop, silver, and the plugin it comes from when that isn't the game itself.
// The quest's line has a switch of its own, the quiet tags are the rest. Last of all on a follower's piece, which mod
// put it on them or took it off
Equipment.quietLines = function(entry)
{
   var lines = [];
   var tags = Equipment.settings.quietTags;
   var slots = Equipment.settings.slotNumbers ? Equipment.bodySlotsLine(entry) : "";
   var quest = Equipment.settings.questLine ? Equipment.questLine(entry) : "";
   var carried = Equipment.number(entry.equipmentCarried);
   var changed = Equipment.changedLine(entry);
   if(quest != "")
   {
      lines.push(quest);
   }
   if(slots != "")
   {
      lines.push(slots);
   }
   if(tags && carried > 0 && !Equipment.own(entry, Equipment.ownFlags()) && Equipment.lineShown("have"))
   {
      lines.push(Equipment.say("You have #", carried));
   }
   if(tags && Equipment.silver(entry) && Equipment.lineShown("silver"))
   {
      lines.push(Equipment.say("Silver"));
   }
   if(tags && Equipment.settings.modOrigin && entry.equipmentOrigin != undefined && entry.equipmentOrigin != "")
   {
      lines.push(Equipment.say("From #", entry.equipmentOrigin));
   }
   if(changed != "")
   {
      lines.push(changed);
   }
   return lines;
};

// Which mod last put a piece on the follower of the trade or took it off, as the plugin noted it: a script's mod or
// a plugin's DLL, never the player, the panel or the game's own dressing. The player's own change of the piece
// clears it. Only their side and their slots, a piece of their outfit has no row and is theirs. The player's rows
// and own inventory have none
Equipment.changedLine = function(entry)
{
   var plugin;
   var told;
   if(!Equipment.dressesOther() || entry.formId == undefined || entry.outfit != true && Equipment.own(entry, Equipment.ownFlags()))
   {
      return "";
   }
   plugin = Equipment.plugin();
   told = plugin != undefined && plugin.ChangedBy != undefined ? plugin.ChangedBy(entry.formId) : undefined;
   if(told == undefined || told.by == undefined || String(told.by) == "")
   {
      return "";
   }
   return "! " + (told.on == true ? Equipment.say("Put on #1 by #2", told.name, told.by) : Equipment.say("Taken off #1 by #2", told.name, told.by));
};

// for tests, the numbers of an item with their changes against the worn ones, and what they're weighed against
Equipment.wornArmorReport = function(worn)
{
   var told = [];
   var i = 0;
   while(worn != undefined && i < worn.armor.length)
   {
      told.push(worn.armor[i].text + " " + worn.armor[i].infoArmor + (worn.armor[i].outfit == true ? " outfit" : ""));
      i++;
   }
   return told.join(", ");
};

Equipment.statsReport = function(formId)
{
   var entries = Equipment.menu.inventoryLists.itemList.entryList;
   var worn = Equipment.wornNow;
   var lines;
   var told;
   var i = 0;
   var j;
   while(i < entries.length)
   {
      if(entries[i].formId == Number(formId))
      {
         lines = Equipment.statsOf(entries[i]);
         told = [];
         j = 0;
         while(j < lines.length)
         {
            told.push(lines[j][0] + " " + lines[j][1] + (lines[j][2] != undefined ? " " + lines[j][2].role + (lines[j][2].text != undefined ? " " + Equipment.bracketed(lines[j][2]) : "") : ""));
            j++;
         }
         skse.Log("PANELTEST stats " + entries[i].text + " against " + (worn != undefined && worn.right != undefined ? worn.right.text : "nothing") + ": " + told.join(" | ") + (entries[i].formType == Equipment.ARMOR ? " || armor " + entries[i].infoArmor + " worn " + entries[i].equipState + ", the set " + Equipment.wornArmorReport(worn) : ""));
      }
      i++;
   }
};

// for tests, the quiet lines of every row of an item, the rows of both sides of a chest each
Equipment.quietReport = function(formId)
{
   var entries = Equipment.menu.inventoryLists.itemList.entryList;
   var flags = Equipment.ownFlags();
   var i = 0;
   while(i < entries.length)
   {
      if(entries[i].formId == Number(formId))
      {
         skse.Log("PANELTEST quiet " + entries[i].text + (Equipment.own(entries[i], flags) ? " (own)" : " (theirs)") + ": " + Equipment.quietLines(entries[i]).join(" / ") + "; quest " + entries[i].equipmentQuest + " " + entries[i].equipmentQuestName);
      }
      i++;
   }
};

// for tests, what the plugin and the game say of the stolen copies of every row of an item, and its line
Equipment.stolenReport = function(formId)
{
   var entries = Equipment.menu.inventoryLists.itemList.entryList;
   var i = 0;
   while(i < entries.length)
   {
      if(entries[i].formId == Number(formId))
      {
         skse.Log("PANELTEST stolen " + entries[i].text + " x" + entries[i].count + ": plugin " + entries[i].equipmentStolen + ", game " + entries[i].isStolen + ", line \"" + Equipment.stolenLine(entries[i]) + "\"");
      }
      i++;
   }
};

// for tests, the list scrolls so the row with this text is in sight, a few rows from the top
Equipment.scrollToRowNamed = function(text)
{
   var list = Equipment.menu.inventoryLists.itemList;
   var i = 0;
   while(i < list.listEnumeration.size() && list.listEnumeration.at(i).text != String(text))
   {
      i++;
   }
   skse.Log("PANELTEST row " + text + " is at " + i + " of " + list.listEnumeration.size());
   if(i < list.listEnumeration.size())
   {
      list.scrollPosition = Math.max(0, Math.min(i - 3, list._maxScrollPosition));
      list.requestUpdate();
   }
};

// for tests, the list scrolls so the row of this item is in sight, a few rows from the top. In a follower's trade a
// scroll from here followed by a category switch left SkyUI's card on a row of the other side, the wheel never did
Equipment.scrollToForm = function(formId)
{
   var list = Equipment.menu.inventoryLists.itemList;
   var i = 0;
   while(i < list.listEnumeration.size() && list.listEnumeration.at(i).formId != Number(formId))
   {
      i++;
   }
   if(i < list.listEnumeration.size())
   {
      list.scrollPosition = Math.max(0, Math.min(i - 3, list._maxScrollPosition));
      list.requestUpdate();
   }
};

// for tests, every row a quest wants something with, and how many rows come from a mod
Equipment.questReport = function(note)
{
   var entries = Equipment.menu.inventoryLists.itemList.entryList;
   var found = [];
   var mods = 0;
   var i = 0;
   while(i < entries.length)
   {
      if(Equipment.number(entries[i].equipmentQuest) > 0)
      {
         found.push(entries[i].text + " = " + Equipment.questLine(entries[i]));
      }
      mods += entries[i].equipmentOrigin != undefined ? 1 : 0;
      i++;
   }
   skse.Log("PANELTEST quests " + note + ": " + entries.length + " rows, " + mods + " from mods, " + found.length + " a quest wants: " + found.join(" | "));
};

// What the plugin found a quest wants with the item, see Quests.h of the plugin. Every line says first whether the
// item is still needed. A quest with no name of its own is named by the place of what it holds
Equipment.questLine = function(entry)
{
   var name = entry.equipmentQuestName != undefined ? String(entry.equipmentQuestName) : "";
   var place = entry.equipmentQuestPlace == true && name != "";
   switch(Equipment.number(entry.equipmentQuest))
   {
      case 1:
      case 5:
         return place ? Equipment.say("Still needed for a quest at #", name) : (name != "" ? Equipment.say("Still needed for #", name) : Equipment.say("Still needed for a quest"));
      case 2:
         return name != "" ? Equipment.say("Still needed, # follows it", name) : Equipment.say("Still needed, a quest follows it");
      case 3:
         return name != "" ? Equipment.say("Still needed, # asks for it", name) : Equipment.say("Still needed, a quest asks for it");
      case 4:
         return name != "" ? Equipment.say("No longer needed, # is done", name) : Equipment.say("No longer needed, its quest is done");
      case 6:
         return place ? Equipment.say("Needed later for a quest at #", name) : (name != "" ? Equipment.say("Needed later, # hasn't begun", name) : Equipment.say("Needed later for a quest not begun yet"));
      case 7:
         return place ? Equipment.say("No longer needed, the quest at # is over", name) : (name != "" ? Equipment.say("No longer needed, # is over", name) : Equipment.say("No longer needed, its quest is over"));
   }
   return "";
};

// the kinds of quest lines that keep an item, see questLine
Equipment.questNeeds = function(entry)
{
   var quest = Equipment.number(entry.equipmentQuest);
   return quest >= 1 && quest <= 3 || quest == 5 || quest == 6;
};

// silver weapons hurt the undead more, mods name their silver with a material keyword like the game's
Equipment.silver = function(entry)
{
   var word;
   for(var name in entry.keywords)
   {
      word = name.toLowerCase();
      if(word.indexOf("silver") >= 0 && word.indexOf("material") >= 0)
      {
         return true;
      }
   }
   return false;
};

Equipment.bodySlotsHeight = function()
{
   var line = Equipment.window.bodySlots;
   return line._visible ? line._height : 0;
};

Equipment.placeStats = function(window, top)
{
   var pad = Equipment.STATS_PAD;
   var high = Equipment.statsTextHigh(window) + 4;
   var valuesWide = Equipment.valuesWide(window);
   window.statNames._x = pad;
   window.statValues._x = window.wide - pad - valuesWide;
   window.statNames._y = window.statValues._y = top + pad / 2;
   window.statNames._width = window.wide - 2 * pad - valuesWide;
   window.statValues._width = valuesWide;
   window.statNames._height = window.statValues._height = high;
   window.statGrid._x = pad;
   window.statGrid._y = top + pad / 2;
   window.statGrid._width = window.wide - 2 * pad;
   window.statGrid._height = high;
   window.stolen._x = pad;
   window.stolen._y = top + Equipment.statsHeight() + Equipment.STOLEN_GAP / 2;
   window.extra._x = pad;
   window.extra._y = top + Equipment.statsHeight() + Equipment.stolenHeight() + Equipment.STOLEN_GAP / 2;
   Equipment.placeBodySlots(window, top + Equipment.statsHeight() + Equipment.stolenHeight() + Equipment.extraHeight());
};

// right under the numbers, a window of a row has the strip of the lens there and the line sits in it
Equipment.placeBodySlots = function(window, top)
{
   var line = window.bodySlots;
   var room = Equipment.anchorSlot != undefined ? line._height : Math.max(Equipment.LENS_SIZE, line._height);
   line._x = Equipment.STATS_PAD;
   line._y = top + (room - line._height) / 2;
};

// the game's body slots 30 to 61 a mask holds, bit n is slot 30 + n
Equipment.bodySlots = function(mask)
{
   var bits = Equipment.number(mask);
   var slots = [];
   var i = 0;
   while(i < 32)
   {
      if((bits & (1 << i)) != 0)
      {
         slots.push(Equipment.FIRST_BODY_SLOT + i);
      }
      i++;
   }
   return slots;
};

// Slots 32, 46 for a piece to wear. Anything else you wear or hold says it takes no body slot: weapons, torches,
// arrows and jewelry MARA took the slots off. A potion or a book says nothing
Equipment.bodySlotsLine = function(entry)
{
   var slots = entry.formType == Equipment.ARMOR ? Equipment.bodySlots(entry.partMask) : [];
   if(slots.length > 0)
   {
      return slots.length == 1 ? Equipment.say("Slot #", slots[0]) : Equipment.say("Slots #", slots.join(", "));
   }
   if(entry.formType == Equipment.ARMOR && entry.partMask == undefined)
   {
      return "";
   }
   return Equipment.has([Equipment.ARMOR, Equipment.WEAPON, Equipment.AMMO, Equipment.LIGHT], entry.formType) ? Equipment.say("No body slot") : "";
};

Equipment.fixed = function(value, digits)
{
   var power = Math.pow(10, digits);
   var text = String(Math.round(value * power) / power);
   if(digits > 0 && text.indexOf(".") < 0)
   {
      text += ".";
      while(digits > 0)
      {
         text += "0";
         digits--;
      }
   }
   return text;
};

Equipment.seconds = function(value)
{
   return Equipment.say("# s", value);
};

// a share of 1 as a percent with one digit
Equipment.percent = function(share)
{
   return Equipment.fixed(share * 100, 1) + "%";
};

Equipment.statsOf = function(entry)
{
   var told = Equipment.plugin() != undefined ? Equipment.plugin().Stats(entry.formId) : undefined;
   if(told == undefined)
   {
      return [];
   }
   if(entry.formType == Equipment.WEAPON && told.kind == "weapon")
   {
      return Equipment.weaponStats(entry, told);
   }
   if(entry.formType == Equipment.ARMOR && told.kind == "armor")
   {
      return Equipment.armorStats(entry, told);
   }
   return [];
};

Equipment.swingOf = function(entry)
{
   if(Equipment.isBow(entry))
   {
      return Equipment.SWING.bow;
   }
   if(Equipment.isCrossbow(entry))
   {
      return Equipment.SWING.crossbow;
   }
   return Equipment.twoHanded(entry) ? Equipment.SWING.twoHanded : Equipment.SWING.oneHanded;
};

// Worn by the one the panel shows. A body or a mannequin keeps its worn rows marked worn too, those are only things
// to take
Equipment.wornByShown = function(entry)
{
   return entry.outfit == true || Equipment.wornByPlayer(entry, Equipment.wearerFlags());
};

// The raw numbers of a weapon: when a blow lands, damage a second, reach, stagger and crit damage. A bow or
// crossbow counts the worn ammo it shoots with it. A staff has none
Equipment.weaponNumbers = function(entry, told)
{
   var worn = Equipment.wornNow;
   var swing = Equipment.swingOf(entry);
   var left = entry.equipState == Equipment.LEFT_HAND && Equipment.wornByShown(entry);
   var pace = Math.max(told.speed, 0.05) * Math.max(left ? told.leftSpeedMult : told.speedMult, 0.05);
   var damage = Equipment.number(entry.infoDamage);
   var ammo = worn != undefined && worn.ammo != undefined && Equipment.shoots(entry, worn.ammo) ? worn.ammo : undefined;
   if(entry.subType == Equipment.STAFF)
   {
      return undefined;
   }
   if(ammo != undefined)
   {
      damage += Equipment.number(ammo.infoDamage);
   }
   return {hit:swing.hit / pace, damage:damage, perSecond:damage / (swing.cycle / pace), reach:told.reach, stagger:told.stagger, critDamage:told.critDamage, ammo:ammo};
};

// What a weapon that isn't in the hands is weighed against: the one the row arrow weighs it against
Equipment.weaponAgainst = function(entry)
{
   var worn = Equipment.wornNow;
   var held = worn != undefined && !Equipment.wornByPlayer(entry, Equipment.wearerFlags()) ? Equipment.heldLike(entry, worn) : undefined;
   var told = held != undefined && Equipment.plugin() != undefined ? Equipment.plugin().Stats(held.formId) : undefined;
   return told != undefined && told.kind == "weapon" ? Equipment.weaponNumbers(held, told) : undefined;
};

// Swing time, damage a second and a minute of steady blows, reach, stagger and crit damage, each with how much
// it beats the weapon in the hands
Equipment.weaponStats = function(entry, told)
{
   var lines = [];
   var mine = Equipment.weaponNumbers(entry, told);
   var held;
   var sameShot;
   if(mine == undefined)
   {
      return lines;
   }
   held = Equipment.weaponAgainst(entry);
   // the worn arrows go with a bow only, a bow and a crossbow would count them on one side
   sameShot = held != undefined && (mine.ammo == undefined) == (held.ammo == undefined);
   Equipment.addNumber(lines, "swing", [Equipment.ranged(entry) ? Equipment.say("Draw") : Equipment.say("Swing"), Equipment.seconds(Equipment.fixed(mine.hit, 2)), held != undefined ? Equipment.change(mine.hit - held.hit, 2, -1) : undefined]);
   if(mine.damage > 0)
   {
      Equipment.addNumber(lines, "dps", [mine.ammo != undefined ? Equipment.say("DPS (with #)", mine.ammo.text) : Equipment.say("DPS"), "~" + Equipment.fixed(mine.perSecond, 1), sameShot ? Equipment.change(mine.perSecond - held.perSecond, 1, 1) : undefined]);
      Equipment.addNumber(lines, "dpm", [Equipment.say("DPM"), "~" + Math.round(mine.perSecond * 60), sameShot ? Equipment.change(Math.round(mine.perSecond * 60) - Math.round(held.perSecond * 60), 0, 1) : undefined]);
   }
   if(!Equipment.ranged(entry))
   {
      Equipment.addNumber(lines, "reach", [Equipment.say("Reach"), Equipment.fixed(mine.reach, 2), held != undefined ? Equipment.change(mine.reach - held.reach, 2, 1) : undefined]);
   }
   Equipment.addNumber(lines, "stagger", [Equipment.say("Stagger"), Equipment.fixed(mine.stagger, 2), held != undefined ? Equipment.change(mine.stagger - held.stagger, 2, 1) : undefined]);
   if(mine.critDamage > 0 || held != undefined && held.critDamage > 0)
   {
      Equipment.addNumber(lines, "crit", [Equipment.say("Crit damage"), String(mine.critDamage), held != undefined ? Equipment.change(mine.critDamage - held.critDamage, 0, 1) : undefined]);
   }
   return lines;
};

// The lines of the numbers and the small lines the player switches off one by one, in the order of their bits in
// numbersOff and linesOff, with their ids in the menu of the mod
Equipment.NUMBER_LINES = [
   {name:"swing", id:"bSwing:Numbers"}, {name:"dps", id:"bDPS:Numbers"}, {name:"dpm", id:"bDPM:Numbers"},
   {name:"reach", id:"bReach:Numbers"}, {name:"stagger", id:"bStagger:Numbers"}, {name:"crit", id:"bCritDamage:Numbers"},
   {name:"stops", id:"bStops:Numbers"}, {name:"set", id:"bWholeSet:Numbers"}, {name:"health", id:"bEffectiveHealth:Numbers"},
   {name:"perWeight", id:"bArmorPerWeight:Numbers"}
];
Equipment.SMALL_LINES = [{name:"kind", id:"bKind:Lines"}, {name:"have", id:"bHave:Lines"}, {name:"silver", id:"bSilver:Lines"}, {name:"stolen", id:"bStolen:Lines"}];

// where a line stands in its list and so which bit it has, -1 for none
Equipment.lineAt = function(lines, name)
{
   var i = 0;
   while(i < lines.length && lines[i].name != name)
   {
      i++;
   }
   return i < lines.length ? i : -1;
};

// a line of a list is shown unless the bit of its place is set in the mask
Equipment.lineOn = function(mask, lines, name)
{
   var off = Equipment.settings != undefined ? Equipment.number(Equipment.settings[mask]) : 0;
   return (off & 1 << Equipment.lineAt(lines, name)) == 0;
};

Equipment.numberShown = function(name)
{
   return Equipment.lineOn("numbersOff", Equipment.NUMBER_LINES, name);
};

Equipment.lineShown = function(name)
{
   return Equipment.lineOn("linesOff", Equipment.SMALL_LINES, name);
};

Equipment.addNumber = function(lines, name, line)
{
   if(Equipment.numberShown(name))
   {
      line.key = name;
      lines.push(line);
   }
};

// How much a number beats the one of what's worn or held in its place, the third part of a line of numbers. Its
// ink says better or worse, more is better unless better is -1. Too little to show at those digits is equal.
// A change with no text colours the value itself, for a line whose value already is the change
Equipment.change = function(amount, digits, better)
{
   var text = Equipment.fixed(Math.abs(amount), digits);
   if(Number(text) == 0)
   {
      return {text:"=", role:"equal"};
   }
   return {text:(amount > 0 ? "+" : "-") + text, role:amount * better > 0 ? "better" : "worse"};
};

// a change of a share as a percent with its sign, more is better
Equipment.percentChange = function(share)
{
   var told = Equipment.change(share * 100, 1, 1);
   if(told.text != "=")
   {
      told.text += "%";
   }
   return told;
};

// light or heavy armor, shields too. Clothing and jewelry don't count as pieces of armor
Equipment.armorPiece = function(entry)
{
   return entry.weightClass == 0 || entry.weightClass == 1 ? 1 : 0;
};

// The share of a hit a rating stops with that many worn pieces of armor, before the cap. The plugin asks the game's
// own sum, so a mod that rewrote it (Blade and Blunt, Armor Rating Rescaled) counts here as in its hits. Without the
// plugin's answer the game's settings make it: a fixed rate of the rating and a fixed share for every piece
Equipment.armorShare = function(rating, pieces, told)
{
   var hidden = pieces * told.armorBase;
   var plugin = Equipment.plugin();
   var share = plugin != undefined && plugin.ArmorStops != undefined ? plugin.ArmorStops(rating, hidden) : undefined;
   if(typeof share != "number" || isNaN(share))
   {
      return rating * told.armorScale / 100 + hidden;
   }
   return share;
};

// What share of a hit a piece stops. The game turns armor rating into damage stopped (at a fixed rate, or the way a mod
// rewrote it), adds a share for every worn piece of armor and stops at a cap, so a piece counts for less past the cap.
// A worn piece shows what it adds to the set, another one what it would add in place of the worn pieces it shares a slot with
Equipment.armorStats = function(entry, told)
{
   var lines = [];
   var worn = Equipment.wornNow;
   var cap = told.armorCap / 100;
   var rating = Equipment.number(entry.infoArmor);
   var piece = Equipment.armorPiece(entry);
   var total = 0;
   var pieces = 0;
   var replaced = 0;
   var replacedPieces = 0;
   var i = 0;
   var replacedWeight = 0;
   var before;
   var after;
   var without;
   var swaps;
   var weight = Equipment.number(entry.infoWeight);
   var on = Equipment.wornByShown(entry);
   while(worn != undefined && i < worn.armor.length)
   {
      total += Equipment.number(worn.armor[i].infoArmor);
      pieces += Equipment.armorPiece(worn.armor[i]);
      if(!on && (worn.armor[i].partMask & entry.partMask))
      {
         replaced += Equipment.number(worn.armor[i].infoArmor);
         replacedPieces += Equipment.armorPiece(worn.armor[i]);
         replacedWeight += Equipment.number(worn.armor[i].infoWeight);
      }
      i++;
   }
   if(on)
   {
      before = Math.min(Equipment.armorShare(total - rating, pieces - piece, told), cap);
      after = Math.min(Equipment.armorShare(total, pieces, told), cap);
      without = before;
   }
   else
   {
      before = Math.min(Equipment.armorShare(total, pieces, told), cap);
      after = Math.min(Equipment.armorShare(total - replaced + rating, pieces - replacedPieces + piece, told), cap);
      without = Math.min(Equipment.armorShare(total - replaced, pieces - replacedPieces, told), cap);
   }
   if(rating <= 0 && replaced <= 0)
   {
      return lines;
   }
   // What the piece itself stops in the set, and in brackets the change against the worn pieces it would take the
   // place of, as a weapon against the held one
   swaps = !on && (replaced > 0 || replacedPieces > 0);
   Equipment.addNumber(lines, "stops", [on ? Equipment.say("Stops") : Equipment.say("Would stop"), Equipment.say("# of a hit", Equipment.percent(after - without)), swaps ? Equipment.percentChange(after - before) : undefined]);
   Equipment.addNumber(lines, "set", [Equipment.say("Whole set"), Equipment.say("#1 (cap #2)", Equipment.percent(after), Equipment.percent(cap))]);
   // a mod that lets armor stop every hit would make this endless, the line says nothing then
   if(after < 1)
   {
      Equipment.addNumber(lines, "health", [Equipment.say("Effective health"), "+" + Equipment.percent((1 - without) / (1 - after) - 1), swaps ? Equipment.percentChange((1 - before) / (1 - after) - 1) : undefined]);
   }
   if(weight > 0 && rating > 0)
   {
      Equipment.addNumber(lines, "perWeight", [Equipment.say("Armor per weight"), Equipment.fixed(rating / weight, 2), replacedWeight > 0 && replaced > 0 ? Equipment.change(rating / weight - replaced / replacedWeight, 2, 1) : undefined]);
   }
   return lines;
};
