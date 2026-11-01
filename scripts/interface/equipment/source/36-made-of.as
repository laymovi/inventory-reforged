// What the item is made of, a small list in the top left corner of the item window's model room, a choice in the
// settings. [Lines] iMadeOf, madeOf here, is 0 for nothing, 1 for the material its keywords name (Steel Plate) and 2
// for every part of the recipe that makes it with how many it takes (Iron Ingot (4)). The plugin finds the recipe in
// its index of the records, an enchanted piece by the plain one, and hands the parts over with the item's numbers
// (Stats). An item no recipe makes says its material, one with neither says nothing at all. One of the quiet tags, in
// their letters, ink and size. The model keeps clear of it (the plugin's OutOfCorner). A station that writes what its
// recipe takes keeps the corner empty, the card in the UI's place has no window and so no corner
Equipment.MADE_OF_OFF = 0;
Equipment.MADE_OF_MATERIAL = 1;
Equipment.MADE_OF_PARTS = 2;
// the corner takes this much of the room's width at most in one column and in two, a longer name is cut short
Equipment.MADE_OF_WIDE = 0.45;
Equipment.MADE_OF_TWO_WIDE = 0.7;
Equipment.MADE_OF_COLUMN_GAP = 10;
// lines drawn closer by this share of their letters' size
Equipment.MADE_OF_TIGHT = 0.2;
// the letters get no smaller than this before a last line counts the parts left out, a count says at least this many
Equipment.MADE_OF_SMALLEST = 9;
Equipment.MADE_OF_COUNT_LEAST = 3;
// the air the model keeps from the corner's words
Equipment.MADE_OF_GAP = 6;
Equipment.MADE_OF_DEPTH = 9;
// What a broken record of a mod can't push past. The plugin hands over 32 parts of a recipe at most and counts the
// rest, a name of 200 letters at most, the corner takes no more whatever comes. A count stays what an int holds
Equipment.MADE_OF_MOST = 32;
Equipment.MADE_OF_NAME_MOST = 200;
Equipment.MADE_OF_COUNT_MOST = 2147483647;

Equipment.buildMadeOf = function(window)
{
   var names = ["madeOf", "madeOfSide"];
   var field;
   var i = 0;
   while(i < names.length)
   {
      window.createTextField(names[i], Equipment.MADE_OF_DEPTH + i, 0, 0, 10, 10);
      field = window[names[i]];
      Equipment.styleText(field, Equipment.BODY_SLOTS_TEXT, "left", Equipment.inkOf("quiet"));
      field.multiline = true;
      field.wordWrap = false;
      field._visible = false;
      i++;
   }
   window.madeOfLines = [];
};

// the corner's lines for an item, the head first, none when it has nothing to say
Equipment.madeOfLines = function(entry)
{
   return Equipment.madeOfList(entry).lines;
};

// The lines and how many parts past them the corner only counts, those the plugin left out of a recipe of a hundred
Equipment.madeOfList = function(entry)
{
   var mode = Equipment.number(Equipment.settings.madeOf);
   var made = {parts:[], more:0};
   var material;
   if(entry == undefined || mode == Equipment.MADE_OF_OFF || Equipment.settings.quietTags != true)
   {
      return {lines:[], more:0};
   }
   if(mode == Equipment.MADE_OF_PARTS)
   {
      made = Equipment.madeOfParts(entry);
   }
   if(made.parts.length == 0)
   {
      material = Equipment.material(entry);
      made = {parts:material != "" ? [material] : [], more:0};
   }
   return {lines:made.parts.length > 0 ? [Equipment.say("Made from")].concat(made.parts) : [], more:made.more};
};

// The parts of the item's recipe as the plugin tells them, Iron Ingot (2), and a single one with no count. The first
// MADE_OF_MOST of them, whatever the plugin sent, the rest only counted
Equipment.madeOfParts = function(entry)
{
   var told = Equipment.plugin() != undefined ? Equipment.plugin().Stats(entry.formId) : undefined;
   var made = told != undefined ? told.madeOf : undefined;
   var total = made != undefined ? Equipment.number(made.length) : 0;
   var parts = [];
   var count;
   var name;
   var one;
   var i = 0;
   while(i < total && i < Equipment.MADE_OF_MOST)
   {
      one = made[i];
      name = one != undefined ? Equipment.madeOfName(one.name) : "";
      count = one != undefined ? Math.min(Math.round(Equipment.number(one.count)), Equipment.MADE_OF_COUNT_MOST) : 0;
      if(name != "")
      {
         parts.push(count > 1 ? name + " (" + count + ")" : name);
      }
      i++;
   }
   return {parts:parts, more:Math.max(0, total - i) + Math.max(0, Math.round(Equipment.number(told != undefined ? told.madeOfMore : 0)))};
};

// A name on one line of the corner. The fields take no html, so <b> or & stay letters, but a line break or a tab in a
// broken record would break the line. A name past MADE_OF_NAME_MOST letters is cut, the column cuts it further
Equipment.madeOfName = function(value)
{
   var name = value != undefined ? String(value) : "";
   var first = 0;
   var last;
   if(name.length > Equipment.MADE_OF_NAME_MOST)
   {
      name = name.substr(0, Equipment.MADE_OF_NAME_MOST) + "...";
   }
   name = name.split("\r").join(" ").split("\n").join(" ").split("\t").join(" ");
   last = name.length;
   while(first < last && name.charAt(first) == " ")
   {
      first++;
   }
   while(last > first && name.charAt(last - 1) == " ")
   {
      last--;
   }
   return name.substring(first, last);
};

// The lines for the item the window shows and how high they stand whole in one column, so the window can give the
// model's room that height before it's laid out (previewWanted). They're laid out once the window has its height
// (placeMadeOf)
Equipment.fillMadeOf = function(window)
{
   var entry = Equipment.chargeListUp() ? undefined : Equipment.windowEntry();
   var field = window.madeOf;
   var made = Equipment.madeOfAway(window) ? {lines:[], more:0} : Equipment.madeOfList(entry);
   window.madeOfLines = made.lines;
   window.madeOfMore = made.more;
   window.madeOfNeed = 0;
   if(field != undefined && made.lines.length > 0)
   {
      Equipment.styleMadeOf(field, Equipment.madeOfSize(), false);
      field.text = made.lines.concat(made.more > 0 ? [Equipment.say("and # more", made.more)] : []).join("\n");
      window.madeOfNeed = field.textHeight + 4;
   }
};

// The model's room as high as the whole list needs, its usual height at the least. The room starts under the frame's
// top edge, as high as its bottom edge (frameEdge)
Equipment.previewWanted = function(window)
{
   var need = Equipment.number(window.madeOfNeed);
   var pad = Equipment.WINDOW_PAD;
   return need > 0 ? Math.max(Equipment.PREVIEW_HEIGHT, Math.ceil(Equipment.frameEdge() + pad / 2 + need + pad)) : Equipment.PREVIEW_HEIGHT;
};

Equipment.madeOfSize = function()
{
   return Math.round(Equipment.BODY_SLOTS_TEXT * Equipment.textShare("quiet"));
};

// the small lines' letters and ink at a size, the lines drawn closer or at their own spacing
Equipment.styleMadeOf = function(field, size, tight)
{
   var format;
   Equipment.styleText(field, size, "left", Equipment.inkOf("quiet"));
   format = field.getNewTextFormat();
   format.leading = tight ? -Math.round(size * Equipment.MADE_OF_TIGHT) : 0;
   field.setNewTextFormat(format);
};

// A station that writes what its recipe takes under the numbers has said it already, a corner beside it would name
// another recipe (the forge's ingots against a grindstone's one)
Equipment.madeOfAway = function(window)
{
   return Equipment.crafting == true && window.extra != undefined && window.extra._visible == true;
};

// The list at the top left of the model's room at the size of the small lines, the head over every part in one column
// whenever the room holds them, and the room grows for a long list where the screen lets the window (previewWanted).
// Where it still can't, the head goes first, then the parts take two columns, then their lines come closer, then their
// letters get smaller. Only after all that does a last line count the parts left out, never for one or two of them. A
// name too long for its column is cut short
Equipment.MADE_OF_WAYS = [{head:true, columns:1, tight:false}, {head:false, columns:1, tight:false}, {head:false, columns:2, tight:false}, {head:false, columns:2, tight:true}];
Equipment.placeMadeOf = function(window)
{
   var lines = window.madeOfLines;
   var pad = Equipment.WINDOW_PAD;
   var top = Equipment.previewTop(window, window.preview) + pad / 2;
   var high = window.preview - pad - top;
   var size = Equipment.madeOfSize();
   var ways = Equipment.MADE_OF_WAYS;
   var i = 0;
   Equipment.hideMadeOf(window);
   if(window.madeOf == undefined || lines == undefined || lines.length == 0)
   {
      return undefined;
   }
   while(i < ways.length)
   {
      if(Equipment.layMadeOf(window, lines, ways[i], size, top, high, false))
      {
         return undefined;
      }
      i++;
   }
   while(size > Equipment.MADE_OF_SMALLEST)
   {
      size--;
      if(Equipment.layMadeOf(window, lines, ways[ways.length - 1], size, top, high, false))
      {
         return undefined;
      }
   }
   Equipment.layMadeOf(window, lines, ways[ways.length - 1], size, top, high, true);
};

Equipment.hideMadeOf = function(window)
{
   var fields = [window.madeOf, window.madeOfSide];
   var i = 0;
   while(i < fields.length)
   {
      if(fields[i] != undefined)
      {
         fields[i]._visible = false;
         fields[i].text = "";
      }
      i++;
   }
   window.madeOfWay = undefined;
};

// The list laid one way, with its head or without, in one column or two, its lines closer or not, its letters at a
// size. Tells whether every part found a place. Counting, it takes its place anyway and the last place says how many
// parts were left out. A count of one or two would hide what fits a row more, those parts take that row. Parts the
// plugin left out of a broken recipe always end the list with a count of their own
Equipment.layMadeOf = function(window, lines, way, size, top, high, counting)
{
   var shown = way.head ? lines : lines.slice(1);
   var more = Equipment.number(window.madeOfMore);
   var whole = shown.length + (more > 0 ? 1 : 0);
   var fields = [window.madeOf, window.madeOfSide];
   var wide = Equipment.madeOfColumnWide(window, way.columns);
   var gap = Equipment.MADE_OF_COLUMN_GAP;
   var counted = false;
   var places;
   var rows;
   var per;
   var left;
   var c = 0;
   var x = Equipment.STATS_PAD;
   Equipment.styleMadeOf(fields[0], size, way.tight);
   fields[0].text = shown.join("\n");
   per = fields[0].textHeight / shown.length;
   // a hair over, a room made for these lines holds them all
   rows = per > 0 ? Math.floor((high - 4) / per + 0.01) : whole;
   places = rows * way.columns;
   if(whole > places && !counting)
   {
      return false;
   }
   left = shown.length - places + 1 + more;
   if(whole > places && left >= Equipment.MADE_OF_COUNT_LEAST && places > 1)
   {
      shown = shown.slice(0, places - 1);
      shown.push(Equipment.say("and # more", left));
      counted = true;
   }
   else if(more > 0)
   {
      shown = shown.concat([Equipment.say("and # more", more)]);
      counted = true;
   }
   rows = Math.ceil(shown.length / way.columns);
   while(c < way.columns)
   {
      Equipment.styleMadeOf(fields[c], size, way.tight);
      Equipment.fillMadeOfColumn(fields[c], shown.slice(c * rows, (c + 1) * rows), wide);
      fields[c]._x = x;
      fields[c]._y = top;
      x += fields[c]._width + gap;
      c++;
   }
   window.madeOfWay = {head:way.head, columns:way.columns, tight:way.tight, size:size, rows:rows, counted:counted};
   return true;
};

// One column's lines, each cut short to the column's width, the field as wide and high as its words
Equipment.fillMadeOfColumn = function(field, lines, wide)
{
   var measure = function(words)
   {
      field.text = words;
      return field.textWidth;
   };
   var cut = [];
   var i = 0;
   while(i < lines.length)
   {
      cut.push(Equipment.cutToFit(lines[i], wide - 4, measure));
      i++;
   }
   field.text = cut.join("\n");
   field._width = Math.min(wide, field.textWidth + 4);
   field._height = field.textHeight + 4;
   field._visible = cut.length > 0;
};

// How wide a column may be in the window's units. Two together keep clear of the lens in the window's top right
Equipment.madeOfColumnWide = function(window, columns)
{
   var pad = Equipment.WINDOW_PAD;
   var room = window.wide - 2 * pad;
   var both;
   if(columns < 2)
   {
      return room * Equipment.MADE_OF_WIDE;
   }
   both = Math.min(room * Equipment.MADE_OF_TWO_WIDE, window.wide - Equipment.STATS_PAD - Equipment.LENS_SIZE - pad);
   return (both - (columns - 1) * Equipment.MADE_OF_COLUMN_GAP) / columns;
};

// the corner's words in the panel's units, both columns
Equipment.madeOfBox = function(window)
{
   var fields = [window.madeOf, window.madeOfSide];
   var across = window.across != undefined ? window.across : 1;
   var box;
   var i = 0;
   while(i < fields.length)
   {
      if(fields[i] != undefined && fields[i]._visible == true)
      {
         box = box == undefined ? {xMin:fields[i]._x, yMin:fields[i]._y, xMax:fields[i]._x + fields[i]._width, yMax:fields[i]._y + fields[i]._height} : box;
         box.xMax = Math.max(box.xMax, fields[i]._x + fields[i]._width);
         box.yMax = Math.max(box.yMax, fields[i]._y + fields[i]._height);
      }
      i++;
   }
   if(box == undefined)
   {
      return undefined;
   }
   return {xMin:window._x + box.xMin * across, yMin:window._y + box.yMin, xMax:window._x + box.xMax * across, yMax:window._y + box.yMax};
};

// The corner as PlacePreview takes it, its right and bottom edges with the air the model keeps, from the middle of the
// model's room in shares of the screen's height like the room. Nothing while the corner is empty
Equipment.madeOfCorner = function(window, middleX, middleY, screen)
{
   var across = window.across != undefined ? window.across : 1;
   var box = screen > 0 ? Equipment.madeOfBox(window) : undefined;
   if(box == undefined)
   {
      return undefined;
   }
   return {right:(box.xMax + Equipment.MADE_OF_GAP * across - middleX) / screen, down:(box.yMax + Equipment.MADE_OF_GAP - middleY) / screen};
};

Equipment.boxesMeet = function(one, other)
{
   return one.xMin < other.xMax && other.xMin < one.xMax && one.yMin < other.yMax && other.yMin < one.yMax;
};

// for tests, the corner's lines, the way they were laid out, its box, the model's room and what is seen of the
// model as the plugin fitted it, all in the panel's units, and whether the model lies under the corner. The corner of
// the window shown is laid out once more under the plugin's clock, what it took on this item: the plugin's Stats with
// the lines, then their layout
Equipment.madeOfReport = function(note)
{
   var window = Equipment.window;
   var entry = Equipment.windowEntry();
   var plugin = Equipment.plugin();
   var field = window.madeOf;
   var side = window.madeOfSide;
   var clock = function()
   {
      return plugin != undefined && plugin.Clock != undefined ? Number(plugin.Clock()) : getTimer();
   };
   var start = clock();
   var filled = start;
   var placed = start;
   var way;
   var shown;
   var corner;
   var seen;
   var screen;
   var model;
   var line = function(box)
   {
      return box != undefined ? Equipment.tenth(box.xMin) + "," + Equipment.tenth(box.yMin) + " to " + Equipment.tenth(box.xMax) + "," + Equipment.tenth(box.yMax) : "none";
   };
   if(window._visible == true && field != undefined)
   {
      Equipment.fillMadeOf(window);
      filled = clock();
      Equipment.placeMadeOf(window);
      placed = clock();
   }
   way = window.madeOfWay;
   shown = field != undefined && field._visible == true && window._visible == true;
   corner = shown ? Equipment.madeOfBox(window) : undefined;
   seen = plugin != undefined && plugin.PreviewSeen != undefined ? plugin.PreviewSeen() : undefined;
   screen = Equipment.screenRect();
   if(seen != undefined && seen.length == 4)
   {
      model = {xMin:screen.x + seen[0] * screen.width, yMin:screen.y + seen[1] * screen.height, xMax:screen.x + seen[2] * screen.width, yMax:screen.y + seen[3] * screen.height};
   }
   skse.Log("PANELTEST made of " + note + ": " + (entry != undefined ? entry.text + " " + entry.formId : "nothing selected") + ", setting " + Equipment.number(Equipment.settings.madeOf) + " tags " + Equipment.settings.quietTags + ", lines \"" + (window.madeOfLines != undefined ? window.madeOfLines.join(" / ") : "") + "\", " + Equipment.number(window.madeOfMore) + " more, shown " + shown + " \"" + (shown ? String(field.text).split("\r").join(" / ") + (side != undefined && side._visible == true ? " | " + String(side.text).split("\r").join(" / ") : "") : "") + "\"" + (way != undefined ? " laid " + (way.head ? "with" : "without") + " the head in " + way.columns + " column(s) of " + way.rows + ", lines " + (way.tight ? "closer" : "as they are") + ", letters " + way.size + (way.counted ? ", counted" : "") : "") + " (" + Math.round(Equipment.number(window.madeOfNeed)) + " high whole, room wanted " + Equipment.previewWanted(window) + ")" + "; in the panel's units corner " + line(corner) + ", model room " + line(window.modelRoom) + ", model seen " + line(model) + ", model under the corner " + (corner != undefined && model != undefined && Equipment.boxesMeet(corner, model)) + "; window " + Math.round(window._x) + "," + Math.round(window._y) + " " + Math.round(Equipment.windowWide()) + "x" + Math.round(window.high) + " preview " + Math.round(window.preview) + " from " + Math.round(window.previewTop) + ", station line " + (window.extra != undefined && window.extra._visible == true) + "; laid again in " + Equipment.tenth(placed - start) + " ms (Stats and lines " + Equipment.tenth(filled - start) + ", layout " + Equipment.tenth(placed - filled) + ")");
};
