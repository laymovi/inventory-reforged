// the button stands in the bottom bar right after the one of the item browser, as high as it
Equipment.LOOK_BUTTON = 22;
Equipment.LOOK_BAR_GAP = 8;
Equipment.LOOK_WIDE = 284;
Equipment.LOOK_PAD = 10;
Equipment.LOOK_LINE = 26;
Equipment.LOOK_SLOT_LINE = 22;
Equipment.LOOK_GAP = 6;
Equipment.LOOK_TEXT = 13;
Equipment.LOOK_ARROW = 18;
Equipment.LOOK_VALUE = 92;
Equipment.LOOK_CHECK = 12;
Equipment.LOOK_ICON = 14;
Equipment.LOOK_SHADE = 92;
// what a press on an arrow does to a number, the ids are those of the menu of the mod. A flag steps between off and
// on and is kept as a switch
Equipment.LOOK_STEPS = {
   dollScale:{id:"iScale:Doll", step:5, least:60, most:140},
   dollRight:{id:"iShiftRight:Doll", step:5, least:-40, most:40},
   dollUp:{id:"iShiftUp:Doll", step:5, least:-40, most:40},
   panelSize:{id:"iPanelSize:Panel", step:4, least:60, most:100},
   panelShift:{id:"iPanelShift:Panel", step:2, least:-20, most:20},
   rowHeight:{id:"iRowHeight:List", step:10, least:100, most:200},
   windowSize:{id:"iSize:Window", step:10, least:70, most:160},
   windowShow:{id:"iPopUp:Window", step:1, least:0, most:2},
   leaveCard:{id:"bLeaveCard:Window", step:1, least:0, most:1, flag:true},
   nameText:{id:"iNameText:Window", step:10, least:80, most:200},
   wordsText:{id:"iWordsText:Window", step:10, least:80, most:200},
   numbersText:{id:"iNumbersText:Window", step:10, least:80, most:200},
   quietText:{id:"iQuietText:Window", step:10, least:80, most:200},
   cardText:{id:"iCardText:Window", step:10, least:80, most:200},
   madeOf:{id:"iMadeOf:Lines", step:1, least:0, most:2}
};
// what a tick switches, by the name of the setting and its id in the menu of the mod
Equipment.LOOK_SWITCHES = {
   doll:"bShow:Doll",
   rowModels:"bRowModels:Slots",
   craftingMenu:"bCraftingMenu:Panel",
   stats:"bStats:Window",
   slotNumbers:"bSlotNumbers:Window",
   quietTags:"bQuietTags:Window",
   modOrigin:"bModOrigin:Window",
   questLine:"bQuestLine:Window",
   questMarks:"bQuestMarks:List",
   arrows:"bArrows:List",
   badges:"bBadges:List"
};

// The look of the panel is set in the inventory, where it shows at once. A small button in the bottom bar, beside
// the eye of Know your Skyrim when it's there, opens a sheet beside the left column of slots, over the list, so the
// doll and both columns stay in sight: the doll on or off, its size and its place, the slots on the panel, the
// width of the item list, the compare arrows and slot signs of the rows, when the item window pops up, its size,
// where its card goes, the size of its words and the card's, which of our lines it writes, and the quest marks of the
// rows. Each change goes into the settings of the mod, the menu of the mod shows the same. Nothing here runs while
// it's shut. On a gamepad Y on the panel opens it (padOpenLook in 39-gamepad.as)
Equipment.buildLook = function()
{
   var menu = Equipment.menu;
   var bar = menu.bottomBar;
   var size = Equipment.LOOK_BUTTON;
   var button = Equipment.clipCall(bar, "createEmptyMovieClip", ["equipmentLookButton", Equipment.clipCall(bar, "getNextHighestDepth", [])]);
   var sheet = Equipment.over.createEmptyMovieClip("equipmentLook", Equipment.over.getNextHighestDepth());
   button.createTextField("touch", 0, 0, 0, size, size);
   button.touch.selectable = false;
   button.createEmptyMovieClip("look", 1);
   button.onRollOver = function()
   {
      this.lit = true;
      Equipment.drawLookButton();
   };
   button.onRollOut = button.onReleaseOutside = function()
   {
      this.lit = false;
      Equipment.drawLookButton();
   };
   button.onPress = function()
   {
      Equipment.toggleLook();
   };
   button.onPressAux = function()
   {
   };
   Equipment.lookButton = button;
   sheet._visible = false;
   Equipment.look = sheet;
   // a press anywhere else closes the sheet after what it pressed had its turn
   Equipment.lookCatcher = {};
   Equipment.lookCatcher.onMouseDown = function()
   {
      var x = _root._xmouse;
      var y = _root._ymouse;
      if(Equipment.look._visible && !Equipment.look.hitTest(x, y, true) && !Equipment.lookButton.hitTest(x, y, true))
      {
         Equipment.closeLook();
      }
   };
   Mouse.addListener(Equipment.lookCatcher);
   menu.lookHandleInput = menu.handleInput;
   menu.handleInput = function(details, pathToFocus)
   {
      if(Equipment.look._visible && Shared.GlobalFunc.IsKeyPressed(details) && details.navEquivalent == gfx.ui.NavigationCode.ESCAPE)
      {
         Equipment.closeLook();
         return true;
      }
      return this.lookHandleInput(details, pathToFocus);
   };
   Equipment.placeLookButton();
};

// Right after the eye button of Know your Skyrim, which follows the hints of SkyUI, or after the hints themselves. A menu
// with no hints has it at the foot of the panel
Equipment.placeLookButton = function()
{
   var button = Equipment.lookButton;
   var browse = Equipment.browseButton;
   var bar = Equipment.menu.bottomBar;
   var spot = Equipment.afterHints(Equipment.LOOK_BUTTON);
   if(button == undefined)
   {
      return undefined;
   }
   // what the sheet sets is kept and drawn by the plugin
   button._visible = Equipment.plugin() != undefined && Equipment.settings.lookButton;
   if(browse != undefined)
   {
      button._x = Math.round(browse._x + browse.wide + Equipment.LOOK_BAR_GAP);
      button._y = browse._y;
   }
   else if(spot != undefined)
   {
      button._x = spot.x;
      button._y = spot.y;
   }
   else
   {
      button._x = Equipment.frame != undefined ? Math.round(Equipment.frame.right / Equipment.squash - bar._x - Equipment.LOOK_BUTTON) : 0;
      button._y = -Equipment.LOOK_BUTTON - 4;
   }
   Equipment.drawLookButton();
};

Equipment.drawLookButton = function()
{
   var button = Equipment.lookButton;
   var size = Equipment.LOOK_BUTTON;
   var lit = button.lit || Equipment.look._visible;
   // the same box as the eye beside it
   button.look.clear();
   button.look.lineStyle(1, Equipment.accentInk(), lit ? 100 : 75, true);
   Equipment.buttonFill(button.look, lit ? 62 : 42);
   Equipment.roundBox(button.look, 0, 0, size, size, 5);
   button.look.endFill();
   button.look.lineStyle();
   Equipment.drawIcon(button.look, "sliders", 3, 3, size - 6, lit ? Equipment.accentInk() : Equipment.inkOf("sign"), 100);
};

Equipment.toggleLook = function()
{
   if(Equipment.look._visible)
   {
      Equipment.closeLook();
   }
   else if(Equipment.listsAnswer())
   {
      Equipment.openLook();
   }
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

// the windows and menus of the panel go and so does the selected row with its window, the sheet lies over a quiet
// list. The rows under it took the pointer, the wheel and a click, a click read a book or drank a potion
Equipment.openLook = function()
{
   Equipment.closePopup();
   Equipment.closeContext();
   Equipment.closePieces();
   Equipment.menu.inventoryLists.itemList.selectedIndex = -1;
   Equipment.wantWindow(false);
   Equipment.makeLook();
   Equipment.look._visible = true;
   Equipment.holdRows(true);
   Equipment.coverLook();
   Equipment.drawLookButton();
};

Equipment.closeLook = function()
{
   if(!Equipment.look._visible)
   {
      return undefined;
   }
   Equipment.look._visible = false;
   Equipment.holdRows(false);
   Equipment.coverLook();
   Equipment.drawLookButton();
};

Equipment.lookOpen = function()
{
   return Equipment.look != undefined && Equipment.look._visible == true;
};

// The model of a row the list selects under the sheet is drawn over the menu, the part of it the sheet lies over
// steps out while the sheet is open
Equipment.coverLook = function()
{
   var sheet = Equipment.look;
   var bounds;
   var from;
   var to;
   if(Equipment.plugin() == undefined)
   {
      return undefined;
   }
   if(!sheet._visible)
   {
      Equipment.plugin().Cover();
      return undefined;
   }
   bounds = sheet.getBounds(Equipment.over);
   from = Equipment.share(bounds.xMin, bounds.yMin);
   to = Equipment.share(bounds.xMax, bounds.yMax);
   Equipment.plugin().Cover(from.x, from.y, to.x, to.y);
};

// The sheet is made anew each time it opens and each time its page turns. Two tabs on top: the panel with the doll,
// the slots and the list, and the item window with its card and every line of it one by one
Equipment.makeLook = function()
{
   var sheet = Equipment.look;
   var pad = Equipment.LOOK_PAD;
   var wide = Equipment.LOOK_WIDE;
   var inner = wide - 2 * pad;
   var y = pad;
   for(var name in sheet)
   {
      if(sheet[name] instanceof MovieClip)
      {
         sheet[name].removeMovieClip();
      }
   }
   sheet.clear();
   // a drawn shape takes no mouse in this game, the touch keeps the rows under the sheet from the pointer
   sheet.createTextField("touch", 0, 0, 0, wide, 10);
   sheet.touch.selectable = false;
   sheet.depth = 1;
   sheet.lines = [];
   sheet.wide = wide;
   y += Equipment.lookTabs(sheet, pad, y, inner);
   y = Equipment.lookPage == "window" ? Equipment.lookWindowPage(sheet, pad, y, inner) : Equipment.lookPanelPage(sheet, pad, y, inner);
   y += pad;
   sheet.high = y;
   sheet.touch._height = y;
   Equipment.panelBox(sheet, wide, y, Equipment.LOOK_SHADE, 40);
   Equipment.placeLook();
   Equipment.showLookValues();
};

// the doll first, then the slots in two columns as the panel has them, then the list. Gives the y under them
Equipment.lookPanelPage = function(sheet, x, y, wide)
{
   var half = wide / 2;
   var slot;
   var i = 0;
   y += Equipment.lookHead(sheet, Equipment.say("Character"), x, y, wide);
   y += Equipment.lookCheck(sheet, "doll", Equipment.say("Show the character"), undefined, x, y, wide, Equipment.LOOK_LINE);
   y += Equipment.lookStepper(sheet, "dollScale", Equipment.say("Size"), "size", x, y, wide);
   y += Equipment.lookStepper(sheet, "dollRight", Equipment.say("Sideways"), "across", x, y, wide);
   y += Equipment.lookStepper(sheet, "dollUp", Equipment.say("Up and down"), "upward", x, y, wide);
   y += Equipment.lookReset(sheet, x, y, wide);
   // the character and the slots at the stations that make gear too, with pieces tried on there
   y += Equipment.lookCheck(sheet, "craftingMenu", Equipment.say("At crafting stations"), undefined, x, y, wide, Equipment.LOOK_LINE);
   y += Equipment.LOOK_GAP;
   y += Equipment.lookHead(sheet, Equipment.say("Slots on the panel"), x, y, wide);
   while(i < Equipment.SLOTS.length)
   {
      slot = Equipment.SLOTS[i];
      Equipment.lookCheck(sheet, "slot" + i, slot.title, slot.icon, x + slot.column * half, y + slot.row * Equipment.LOOK_SLOT_LINE, half - 4, Equipment.LOOK_SLOT_LINE);
      i++;
   }
   y += Equipment.ROWS * Equipment.LOOK_SLOT_LINE;
   // the panel keeps further from the list where a skin or a screen put the slots over the rows, in every menu
   y += Equipment.LOOK_GAP;
   y += Equipment.lookStepper(sheet, "panelSize", Equipment.say("Width"), "size", x, y, wide);
   y += Equipment.lookStepper(sheet, "panelShift", Equipment.say("Sideways"), "across", x, y, wide);
   y += Equipment.LOOK_GAP;
   y += Equipment.lookHead(sheet, Equipment.say("Item list"), x, y, wide);
   y += Equipment.lookStepper(sheet, "rowHeight", Equipment.say("Row height"), "size", x, y, wide);
   y += Equipment.lookChecks(sheet, [["rowModels", Equipment.say("Item pictures")], ["arrows", Equipment.say("Compare arrows")], ["badges", Equipment.say("Slot signs")]], x, y, wide);
   return y;
};

// When the window pops up, its size and where its card goes, the size of its words and of the card in the UI's place,
// then each line of the numbers and each small line, a switch of its group over them. What it's made of steps through
// its three values on the row the material's tick had, so the page keeps its height. Gives the y under them
Equipment.lookWindowPage = function(sheet, x, y, wide)
{
   var line = Equipment.LOOK_SLOT_LINE;
   y += Equipment.lookHead(sheet, Equipment.say("Item window"), x, y, wide);
   y += Equipment.lookStepper(sheet, "windowShow", Equipment.say("Pops up"), "across", x, y, wide);
   y += Equipment.lookStepper(sheet, "windowSize", Equipment.say("Size"), "size", x, y, wide);
   y += Equipment.lookStepper(sheet, "leaveCard", Equipment.say("Card"), "across", x, y, wide);
   y += Equipment.LOOK_GAP;
   y += Equipment.lookHead(sheet, Equipment.say("Text size"), x, y, wide);
   y += Equipment.lookStepper(sheet, "nameText", Equipment.say("Name"), "size", x, y, wide);
   y += Equipment.lookStepper(sheet, "wordsText", Equipment.say("Effects and descriptions"), "size", x, y, wide);
   y += Equipment.lookStepper(sheet, "numbersText", Equipment.say("Numbers"), "size", x, y, wide);
   y += Equipment.lookStepper(sheet, "quietText", Equipment.say("Small lines"), "size", x, y, wide);
   y += Equipment.lookStepper(sheet, "cardText", Equipment.say("Card in the UI's place"), "size", x, y, wide);
   y += Equipment.LOOK_GAP;
   y += Equipment.lookHead(sheet, Equipment.say("Combat numbers"), x, y, wide);
   y += Equipment.lookCheck(sheet, "stats", Equipment.say("Show the numbers"), undefined, x, y, wide, line);
   y += Equipment.lookChecks(sheet, [
      ["swing", Equipment.say("Swing time")], ["dps", Equipment.say("Damage a second")],
      ["dpm", Equipment.say("Damage a minute")], ["reach", Equipment.say("Reach")],
      ["stagger", Equipment.say("Stagger")], ["crit", Equipment.say("Crit damage")],
      ["stops", Equipment.say("Share stopped")], ["set", Equipment.say("Whole set")],
      ["health", Equipment.say("Effective health")], ["perWeight", Equipment.say("Armor per weight")]
   ], x, y, wide);
   y += Equipment.LOOK_GAP;
   y += Equipment.lookHead(sheet, Equipment.say("Small lines"), x, y, wide);
   y += Equipment.lookCheck(sheet, "quietTags", Equipment.say("Quiet tags"), undefined, x, y, wide, line);
   y += Equipment.lookStepper(sheet, "madeOf", Equipment.say("Made from"), "across", x, y, wide, line);
   y += Equipment.lookChecks(sheet, [
      ["kind", Equipment.say("Kind")], ["have", Equipment.say("How many you have")],
      ["silver", Equipment.say("Silver")], ["modOrigin", Equipment.say("Mod it's from")],
      ["slotNumbers", Equipment.say("Body slots")], ["stolen", Equipment.say("Stolen")],
      ["questLine", Equipment.say("Quest line")], ["questMarks", Equipment.say("Quest marks")]
   ], x, y, wide);
   return y;
};

// two tabs side by side, the page shown is lit
Equipment.lookTabs = function(sheet, x, y, wide)
{
   var high = Equipment.LOOK_LINE - 4;
   var half = (wide - Equipment.LOOK_GAP) / 2;
   Equipment.lookTab(sheet, "panel", Equipment.say("Panel"), x, y, half, high);
   Equipment.lookTab(sheet, "window", Equipment.say("Item window"), x + half + Equipment.LOOK_GAP, y, half, high);
   return high + Equipment.LOOK_GAP;
};

Equipment.lookTab = function(sheet, page, words, x, y, wide, high)
{
   var tab = Equipment.lookControl(sheet, "tab" + page, sheet.depth, x, y, wide, high);
   sheet.depth++;
   tab.page = page;
   Equipment.writeLine(tab, "words", 2, words, Equipment.LOOK_TEXT, Equipment.PARCHMENT);
   tab.words._x = Math.round((wide - tab.words._width) / 2);
   tab.words._y = Math.round((high - tab.words._height) / 2);
   tab.draw = Equipment.drawLookTab;
   tab.onPress = function()
   {
      Equipment.turnLook(this.page);
   };
   sheet.lines.push(tab);
};

// as the tabs of the followers over the doll
Equipment.drawLookTab = function(tab)
{
   var shown = tab.page == (Equipment.lookPage == "window" ? "window" : "panel");
   var lit = tab.lit || shown;
   tab.look.clear();
   tab.look.lineStyle(1, Equipment.GOLD, shown ? 100 : (tab.lit ? 90 : 50), true);
   tab.look.beginFill(0, shown ? 70 : (tab.lit ? 62 : 35));
   Equipment.roundBox(tab.look, 0, 0, tab.wide, tab.high, 5);
   tab.look.endFill();
   tab.look.lineStyle();
   tab.words.textColor = lit ? Equipment.GOLD : Equipment.PARCHMENT;
};

Equipment.turnLook = function(page)
{
   if(page == Equipment.lookPage || page == "panel" && Equipment.lookPage == undefined)
   {
      return undefined;
   }
   Equipment.lookPage = page;
   Equipment.makeLook();
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

// Beside the left column of slots and level with the top of the panel, over the list, raised as far as the screen's
// top to keep clear of the bar. A sheet taller than all of that room gets smaller to fit, a skin's bar can stand
// higher than SkyUI's
Equipment.placeLook = function()
{
   var sheet = Equipment.look;
   var top = Equipment.screenRect().y;
   var bottom = Equipment.barTop() - Equipment.MARGIN;
   var scale = bottom - top > 0 && sheet.high > bottom - top ? (bottom - top) / sheet.high : 1;
   sheet._xscale = sheet._yscale = scale * 100;
   sheet._x = Math.round(Equipment.frame.left - Equipment.POPUP_GAP - sheet.wide * scale);
   sheet._y = Math.round(Math.max(top, Math.min(Equipment.frame.top, bottom - sheet.high * scale)));
   if(sheet._visible)
   {
      Equipment.coverLook();
   }
};

// the name of a group in small gold capitals over a thin gold line, as in the character drawer
Equipment.lookHead = function(sheet, words, x, y, wide)
{
   var head = sheet.createEmptyMovieClip("head" + sheet.depth, sheet.depth);
   sheet.depth++;
   head._x = x;
   head._y = y;
   head.next = 0;
   return Equipment.heroHead(head, words, 0, 0, wide) + 2;
};

// a part of the sheet that lights under the pointer and takes a press, it's drawn by its own function
Equipment.lookControl = function(parent, name, depth, x, y, wide, high)
{
   var control = parent.createEmptyMovieClip(name, depth);
   control._x = x;
   control._y = y;
   control.wide = wide;
   control.high = high;
   control.createTextField("touch", 0, 0, 0, wide, high);
   control.touch.selectable = false;
   control.createEmptyMovieClip("look", 1);
   control.onRollOver = function()
   {
      this.lit = true;
      this.draw(this);
   };
   control.onRollOut = control.onReleaseOutside = function()
   {
      this.lit = false;
      this.draw(this);
   };
   return control;
};

// a line with a box that's ticked while the thing is on, a slot has its sign before its name
Equipment.lookCheck = function(sheet, key, words, icon, x, y, wide, high)
{
   var line = Equipment.lookControl(sheet, "line" + sheet.depth, sheet.depth, x, y, wide, high);
   sheet.depth++;
   line.key = key;
   line.icon = icon;
   line.said = words;
   Equipment.writeLine(line, "words", 2, words, Equipment.LOOK_TEXT, Equipment.WHITE);
   line.words._x = Equipment.LOOK_CHECK + 8 + (icon != undefined ? Equipment.LOOK_ICON + 6 : 0);
   line.words._y = Math.round((high - line.words._height) / 2);
   line.draw = Equipment.drawLookCheck;
   line.onPress = function()
   {
      Equipment.flipLook(this.key);
   };
   sheet.lines.push(line);
   return high;
};

// switches two to a line in reading order, each a pair of its setting and its words
Equipment.lookChecks = function(sheet, checks, x, y, wide)
{
   var half = wide / 2;
   var high = Equipment.LOOK_SLOT_LINE;
   var i = 0;
   while(i < checks.length)
   {
      Equipment.lookCheck(sheet, checks[i][0], checks[i][1], undefined, x + (i % 2) * half, y + Math.floor(i / 2) * high, half - 4, high);
      i++;
   }
   return Math.ceil(checks.length / 2) * high;
};

// A name, then a value between two arrows. The line itself takes no press, so its arrows get theirs. One among the
// ticks takes their height
Equipment.lookStepper = function(sheet, key, words, kind, x, y, wide, lineHigh)
{
   var high = lineHigh != undefined ? lineHigh : Equipment.LOOK_LINE;
   var arrow = Equipment.LOOK_ARROW;
   var valueWide = Equipment.LOOK_VALUE;
   var line = sheet.createEmptyMovieClip("line" + sheet.depth, sheet.depth);
   sheet.depth++;
   line._x = x;
   line._y = y;
   line.key = key;
   line.kind = kind;
   line.wide = wide;
   line.high = high;
   line.said = words;
   Equipment.writeLine(line, "words", 1, words, Equipment.LOOK_TEXT, Equipment.PARCHMENT);
   line.words._y = Math.round((high - line.words._height) / 2);
   line.createTextField("value", 2, wide - arrow - valueWide, Math.round((high - 20) / 2), valueWide, 20);
   Equipment.styleText(line.value, Equipment.LOOK_TEXT, "center", Equipment.WHITE);
   line.less = Equipment.lookArrow(line, "less", 3, wide - 2 * arrow - valueWide, -1);
   line.more = Equipment.lookArrow(line, "more", 4, wide - arrow, 1);
   line.draw = Equipment.drawLookStepper;
   sheet.lines.push(line);
   return high;
};

Equipment.lookArrow = function(line, name, depth, x, way)
{
   var size = Equipment.LOOK_ARROW;
   var arrow = Equipment.lookControl(line, name, depth, x, Math.round((line.high - size) / 2), size, size);
   arrow.way = way;
   arrow.draw = Equipment.drawLookArrow;
   arrow.onPress = function()
   {
      Equipment.stepLook(this._parent.key, this.way);
   };
   return arrow;
};

// a small button across the middle that puts the doll back to its size and place
Equipment.lookReset = function(sheet, x, y, wide)
{
   var high = Equipment.LOOK_LINE - 4;
   var button = Equipment.lookControl(sheet, "reset", sheet.depth, x, y + 2, wide, high);
   sheet.depth++;
   Equipment.writeLine(button, "words", 2, Equipment.say("Reset size and place"), Equipment.LOOK_TEXT, Equipment.WHITE);
   button.words._x = Math.round((wide - button.words._width) / 2);
   button.words._y = Math.round((high - button.words._height) / 2);
   button.draw = Equipment.drawLookReset;
   button.onPress = function()
   {
      Equipment.resetDoll();
   };
   sheet.lines.push(button);
   return Equipment.LOOK_LINE + 2;
};

Equipment.showLookValues = function()
{
   var lines = Equipment.look.lines;
   var i = 0;
   while(i < lines.length)
   {
      lines[i].draw(lines[i]);
      i++;
   }
};

Equipment.lookOn = function(key)
{
   if(Equipment.LOOK_SWITCHES[key] != undefined)
   {
      return Equipment.settings[key] == true;
   }
   if(Equipment.lineAt(Equipment.NUMBER_LINES, key) >= 0)
   {
      return Equipment.numberShown(key);
   }
   if(Equipment.lineAt(Equipment.SMALL_LINES, key) >= 0)
   {
      return Equipment.lineShown(key);
   }
   return Equipment.slotShown(Equipment.SLOTS[Number(key.substr(4))]);
};

// A line of the window switched on its own, a bit of its list's mask that goes to the menu under the line's id
Equipment.flipLine = function(lines, mask, key)
{
   var at = Equipment.lineAt(lines, key);
   var off = Equipment.number(Equipment.settings[mask]);
   var shown = (off & 1 << at) != 0;
   Equipment.settings[mask] = shown ? off & ~(1 << at) : off | 1 << at;
   Equipment.tellSetting(lines[at].id, shown);
};

// A part that does nothing while another is off goes quiet: the doll's numbers without the doll, the lines of the
// numbers and their size without the numbers, the quiet tags one by one without the quiet tags, the card's place with
// the UI's own card. The kind under the name and the corner of what it's made of are the window's own, a card left in
// the UI's place has the skin's
Equipment.lookQuiet = function(key)
{
   var settings = Equipment.settings;
   if(key == "dollScale" || key == "dollRight" || key == "dollUp")
   {
      return settings.doll != true;
   }
   // a panel at full width has no room to move
   if(key == "panelShift")
   {
      return Equipment.panelRoom() == 0;
   }
   if(key == "numbersText" || Equipment.lineAt(Equipment.NUMBER_LINES, key) >= 0)
   {
      return settings.stats != true;
   }
   if(key == "kind" || key == "madeOf")
   {
      return settings.quietTags != true || Equipment.window != undefined && Equipment.leavesCard();
   }
   if(key == "have" || key == "silver" || key == "modOrigin")
   {
      return settings.quietTags != true;
   }
   if(key == "leaveCard")
   {
      return Equipment.number(settings.windowShow) == Equipment.WINDOW_OWN_CARD;
   }
   // a card left in the UI's place brings no window over the rows, when it pops up says nothing then
   if(key == "windowShow")
   {
      return settings.leaveCard == true && Equipment.number(settings.windowShow) != Equipment.WINDOW_OWN_CARD;
   }
   return false;
};

// The card goes home or into the window only as the menu opens, until then the sheet says so. The UI's own card
// leaves it too
Equipment.cardLater = function()
{
   var settings = Equipment.settings;
   var home = settings.leaveCard == true || Equipment.number(settings.windowShow) == Equipment.WINDOW_OWN_CARD;
   return Equipment.window != undefined && home != Equipment.leavesCard();
};

// a switch to the UI's own card or from it lays the card out anew, with the next opening
Equipment.popUpLater = function()
{
   return Equipment.window != undefined && (Equipment.number(Equipment.settings.windowShow) == Equipment.WINDOW_OWN_CARD) != (Equipment.ownCard == true);
};

Equipment.drawLookCheck = function(line)
{
   var on = Equipment.lookOn(line.key);
   var look = line.look;
   var box = Equipment.LOOK_CHECK;
   var top = Math.round((line.high - box) / 2);
   look.clear();
   look.beginFill(Equipment.GOLD, line.lit ? 16 : 0);
   Equipment.roundBox(look, 0, 0, line.wide, line.high, 3);
   look.endFill();
   look.lineStyle(1, on || line.lit ? Equipment.GOLD : Equipment.PARCHMENT, on || line.lit ? 100 : 55, true);
   look.beginFill(0, 45);
   Equipment.roundBox(look, 2, top, box, box, 2);
   look.endFill();
   if(on)
   {
      look.lineStyle(2, Equipment.GOLD, 100, true, "normal", "round", "round");
      look.moveTo(5, top + box / 2);
      look.lineTo(2 + box * 0.42, top + box - 3);
      look.lineTo(box - 1, top + 3);
   }
   look.lineStyle();
   if(line.icon != undefined)
   {
      Equipment.drawIcon(look, line.icon, box + 8, Math.round((line.high - Equipment.LOOK_ICON) / 2), Equipment.LOOK_ICON, Equipment.PARCHMENT, on ? 90 : 40);
   }
   line.words.textColor = line.lit ? Equipment.GOLD : (on && !Equipment.lookQuiet(line.key) ? Equipment.WHITE : Equipment.inkOf("quiet", true));
};

// The value in words between the arrows, quiet while it does nothing. A card that moves with the next opening says so
Equipment.drawLookStepper = function(line)
{
   var value = Equipment.number(Equipment.settings[line.key]);
   var quiet = Equipment.lookQuiet(line.key);
   line.words.text = line.key == "leaveCard" && Equipment.cardLater() ? Equipment.say("Card, when reopened") : line.said;
   if(line.key == "windowShow" && Equipment.popUpLater())
   {
      line.words.text = Equipment.say("Pops up, when reopened");
   }
   line.value.text = Equipment.lookWords(line.key, value);
   line.value.textColor = quiet ? Equipment.inkOf("quiet", true) : Equipment.WHITE;
   line.words.textColor = quiet ? Equipment.inkOf("quiet", true) : Equipment.PARCHMENT;
   line.less.can = Equipment.lookStepped(line.key, -1) != value;
   line.more.can = Equipment.lookStepped(line.key, 1) != value;
   Equipment.drawLookArrow(line.less);
   Equipment.drawLookArrow(line.more);
};

// A small box with a sign: minus and plus for the size, arrows the way the doll or the list's edge goes. An arrow at
// the end of its range goes faint
Equipment.drawLookArrow = function(arrow)
{
   var size = Equipment.LOOK_ARROW;
   var look = arrow.look;
   var kind = arrow._parent.kind;
   var lit = arrow.lit && arrow.can;
   var mid = size / 2;
   var reach = 4;
   var turn = arrow.way > 0 ? 1 : -1;
   look.clear();
   look.lineStyle(1, lit ? Equipment.GOLD : Equipment.WHITE, lit ? 90 : 28, true);
   look.beginFill(lit ? Equipment.GOLD : 0, lit ? 22 : 40);
   Equipment.roundBox(look, 0, 0, size, size, 3);
   look.endFill();
   look.lineStyle(1.6, lit ? Equipment.GOLD : Equipment.PARCHMENT, arrow.can ? 100 : 30, true, "normal", "round", "round");
   if(kind == "size")
   {
      look.moveTo(mid - reach, mid);
      look.lineTo(mid + reach, mid);
      if(arrow.way > 0)
      {
         look.moveTo(mid, mid - reach);
         look.lineTo(mid, mid + reach);
      }
   }
   else if(kind == "upward")
   {
      look.moveTo(mid - reach, mid + 2 * turn);
      look.lineTo(mid, mid - 2 * turn);
      look.lineTo(mid + reach, mid + 2 * turn);
   }
   else
   {
      look.moveTo(mid - 2 * turn, mid - reach);
      look.lineTo(mid + 2 * turn, mid);
      look.lineTo(mid - 2 * turn, mid + reach);
   }
   look.lineStyle();
};

Equipment.drawLookReset = function(button)
{
   var look = button.look;
   look.clear();
   look.lineStyle(1, button.lit ? Equipment.GOLD : Equipment.WHITE, button.lit ? 90 : 35, true);
   look.beginFill(button.lit ? Equipment.GOLD : 1710618, button.lit ? 25 : 80);
   Equipment.roundBox(look, 0, 0, button.wide, button.high, 4);
   look.endFill();
   look.lineStyle();
   button.words.textColor = button.lit ? Equipment.GOLD : Equipment.WHITE;
};

// the words of a value: 100%, 10% right, Middle
Equipment.lookWords = function(key, value)
{
   switch(key)
   {
      case "dollScale":
      case "windowSize":
      case "panelSize":
      case "rowHeight":
      case "nameText":
      case "wordsText":
      case "numbersText":
      case "quietText":
      case "cardText":
         return Equipment.say("#%", value);
      case "dollRight":
      case "panelShift":
         return value == 0 ? Equipment.say("Middle") : (value > 0 ? Equipment.say("#% right", value) : Equipment.say("#% left", -value));
      case "dollUp":
         return value == 0 ? Equipment.say("Middle") : (value > 0 ? Equipment.say("#% up", value) : Equipment.say("#% down", -value));
      case "windowShow":
         return [Equipment.say("On hover"), Equipment.say("After a pause"), Equipment.say("UI's own card")][Math.max(0, Math.min(2, value))];
      case "leaveCard":
         return value > 0 ? Equipment.say("UI's place") : Equipment.say("In the window");
      case "madeOf":
         return [Equipment.say("Off"), Equipment.say("Material"), Equipment.say("Components")][Math.max(0, Math.min(2, value))];
   }
   return String(value);
};

// the value a press on an arrow gives, within its range. The panel moves only as far as it narrowed
Equipment.lookStepped = function(key, way)
{
   var steps = Equipment.LOOK_STEPS[key];
   var value = Equipment.number(Equipment.settings[key]) + way * steps.step;
   var most = key == "panelShift" ? Math.min(steps.most, Equipment.panelRoom()) : steps.most;
   var least = key == "panelShift" ? -most : steps.least;
   return Math.max(least, Math.min(most, value));
};

// The doll is made anew at its new size or place, the plugin keeps its turn. The panel at a new width or place is
// laid out again, a wider one pulls its shift back into the room it has. A new text size lays out the window and the
// card where it stands, the way new words on the card do, and so does a new choice of what it's made of
Equipment.stepLook = function(key, way)
{
   var steps = Equipment.LOOK_STEPS[key];
   var value = Equipment.lookStepped(key, way);
   var shift;
   if(value == Equipment.number(Equipment.settings[key]))
   {
      return undefined;
   }
   Equipment.changeSetting(key, steps.id, steps.flag ? value > 0 : value);
   if(key == "panelSize" || key == "panelShift")
   {
      shift = Equipment.lookStepped("panelShift", 0);
      if(shift != Equipment.number(Equipment.settings.panelShift))
      {
         Equipment.changeSetting("panelShift", Equipment.LOOK_STEPS.panelShift.id, shift);
      }
      Equipment.relayout();
   }
   else if(key == "rowHeight")
   {
      Equipment.rowHeightChanged();
   }
   else if(key == "windowSize")
   {
      Equipment.sizeWindow();
      Equipment.showWindow();
   }
   else if(key == "windowShow")
   {
      Equipment.wantWindow(Equipment.menu.inventoryLists.itemList.selectedIndex >= 0);
      Equipment.showWindow();
   }
   else if(key.indexOf("Text") > 0)
   {
      Equipment.showWindow();
      Equipment.cardNumbersLater();
   }
   else if(key == "madeOf")
   {
      Equipment.showWindow();
   }
   else if(key.indexOf("doll") == 0)
   {
      Equipment.showPlayer();
   }
   Equipment.showLookValues();
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

// The doll and the marks of the rows follow a tick at once, the window's lines come with its next filling
Equipment.flipLook = function(key)
{
   var id = Equipment.LOOK_SWITCHES[key];
   if(id != undefined)
   {
      Equipment.changeSetting(key, id, Equipment.settings[key] != true);
   }
   else if(Equipment.lineAt(Equipment.NUMBER_LINES, key) >= 0)
   {
      Equipment.flipLine(Equipment.NUMBER_LINES, "numbersOff", key);
   }
   else if(Equipment.lineAt(Equipment.SMALL_LINES, key) >= 0)
   {
      Equipment.flipLine(Equipment.SMALL_LINES, "linesOff", key);
   }
   else
   {
      Equipment.flipSlot(Equipment.SLOTS[Number(key.substr(4))]);
   }
   if(key == "doll")
   {
      Equipment.showPlayer();
   }
   else if(key == "rowModels")
   {
      Equipment.rowPicturesChanged();
   }
   else if(key == "questMarks" || key == "arrows" || key == "badges")
   {
      Equipment.menu.inventoryLists.itemList.UpdateList();
   }
   Equipment.showLookValues();
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

Equipment.resetDoll = function()
{
   Equipment.changeSetting("dollScale", Equipment.LOOK_STEPS.dollScale.id, 100);
   Equipment.changeSetting("dollRight", Equipment.LOOK_STEPS.dollRight.id, 0);
   Equipment.changeSetting("dollUp", Equipment.LOOK_STEPS.dollUp.id, 0);
   Equipment.showPlayer();
   Equipment.showLookValues();
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

// A slot taken off the panel or put back. Its window, its strip and its filter go with it, the others keep their
// places and the models are made for the slots in sight
Equipment.flipSlot = function(slot)
{
   var index = Equipment.slotIndex(slot);
   var shown = !Equipment.slotShown(slot);
   var off = Equipment.number(Equipment.settings.slotsOff);
   Equipment.settings.slotsOff = shown ? off & ~(1 << index) : off | (1 << index);
   Equipment.tellSetting("bShow" + slot.name.charAt(0).toUpperCase() + slot.name.substr(1) + ":Slots", shown);
   Equipment.closePopup();
   Equipment.closePieces();
   if(!shown && Equipment.activeSlot == slot)
   {
      Equipment.filterSlot(slot);
   }
   Equipment.layout();
   Equipment.showModels(true);
};

// Everything that stands by the list's edge follows it: the slots and the doll's room, the item window, the drawer,
// the subcategories and the models of the slots. The doll follows the room with the models
Equipment.relayout = function()
{
   Equipment.closePopup();
   Equipment.closeContext();
   Equipment.closePieces();
   Equipment.layout();
   Equipment.placeWindowLeft();
   Equipment.placeHero();
   Equipment.placeCompanions();
   Equipment.placeLookButton();
   Equipment.showChips();
   Equipment.wearing = undefined;
   Equipment.showModels();
   Equipment.browserRoomChanged();
   Equipment.placeLook();
};

// for tests, the middle of a part of the sheet as aimedX, aimedY. "button", "reset", "tab,<page>", "doll",
// "slot,<name>", "check,<setting or line>", "less,<key>", "more,<key>"
Equipment.aimLook = function(part)
{
   // Papyrus hands words over in the case the game met them first, "Button" for "button", "Window" for "window"
   var parts = String(part).toLowerCase().split(",");
   var sheet = Equipment.look;
   var clip;
   var lines = sheet.lines;
   var i = 0;
   var bounds;
   var share;
   Equipment.aimedX = Equipment.aimedY = -1;
   if(parts[0] == "button")
   {
      clip = Equipment.lookButton;
   }
   else if(parts[0] == "reset")
   {
      clip = sheet.reset;
   }
   else if(parts[0] == "tab")
   {
      clip = sheet["tab" + parts[1]];
   }
   while(clip == undefined && lines != undefined && i < lines.length)
   {
      if(parts[0] == "doll" && lines[i].key == "doll" || parts[0] == "check" && String(lines[i].key).toLowerCase() == parts[1] || parts[0] == "slot" && lines[i].key == "slot" + Equipment.slotIndex(Equipment.slotNamed(parts[1])))
      {
         clip = lines[i];
      }
      else if((parts[0] == "less" || parts[0] == "more") && String(lines[i].key).toLowerCase() == parts[1])
      {
         clip = lines[i][parts[0]];
      }
      i++;
   }
   if(clip == undefined)
   {
      return undefined;
   }
   bounds = clip.getBounds(_root);
   share = Equipment.screenShare((bounds.xMin + bounds.xMax) / 2, (bounds.yMin + bounds.yMax) / 2);
   Equipment.aimedX = share.x;
   Equipment.aimedY = share.y;
};

// for tests, the look button against the hints before it and the player's numbers after it, on the screen
Equipment.barReport = function(note)
{
   var bar = Equipment.menu.bottomBar;
   var button = Equipment.lookButton;
   var info = bar.playerInfoCard;
   var parts = [];
   var box;
   if(button != undefined)
   {
      box = button.getBounds(_root);
      parts.push("look button " + Math.round(box.xMin) + "-" + Math.round(box.xMax) + " shown " + button._visible);
   }
   if(bar.buttonPanel != undefined)
   {
      box = Equipment.clipCall(bar.buttonPanel, "getBounds", [_root]);
      parts.push("hints " + Math.round(box.xMin) + "-" + Math.round(box.xMax));
   }
   if(info != undefined)
   {
      box = Equipment.clipCall(info, "getBounds", [_root]);
      parts.push("player info " + Math.round(box.xMin) + "-" + Math.round(box.xMax));
   }
   for(var name in bar)
   {
      if(typeof bar[name] == "movieclip" && bar[name]._visible && name != "buttonPanel" && name != "playerInfoCard" && name.indexOf("equipment") != 0)
      {
         box = bar[name].getBounds(_root);
         parts.push(name + " " + Math.round(box.xMin) + "-" + Math.round(box.xMax));
      }
   }
   skse.Log("PANELTEST bar " + note + ": screen " + Math.round(Stage.visibleRect.width) + ", " + parts.join(", "));
};

// for tests, what the sheet set and where the list, the slots and the doll's room stand now
Equipment.lookReport = function(note)
{
   var settings = Equipment.settings;
   var stage = Equipment.stage;
   var off = [];
   var i = 0;
   while(i < Equipment.SLOTS.length)
   {
      if(!Equipment.slotShown(Equipment.SLOTS[i]))
      {
         off.push(Equipment.SLOTS[i].name);
      }
      i++;
   }
   skse.Log("PANELTEST look " + note + ": sheet " + Equipment.look._visible + ", doll " + settings.doll + " " + settings.dollScale + "% right " + settings.dollRight + " up " + settings.dollUp + ", slots off " + (off.length > 0 ? off.join("/") : "-") + ", panel width " + settings.panelSize + "% shift " + settings.panelShift + ", " + Equipment.edgeReport() + ", room " + Math.round(stage._x) + ".." + Math.round(stage._x + stage.touch._width) + ", cells " + Equipment.cells().length + ", window stats " + settings.stats + " slots " + settings.slotNumbers + " tags " + settings.quietTags + " mod " + settings.modOrigin + " quest line " + settings.questLine + " marks " + settings.questMarks + " arrows " + settings.arrows + " badges " + settings.badges + " numbers off " + Equipment.number(settings.numbersOff) + " lines off " + Equipment.number(settings.linesOff) + " made of " + Equipment.number(settings.madeOf) + ", page " + (Equipment.lookPage == "window" ? "window" : "panel") + ", card left " + settings.leaveCard + " as opened " + Equipment.leavesCard() + ", window up " + Equipment.window._visible + " numbers " + Equipment.window.statLines.length + " small lines '" + Equipment.window.bodySlots.text + "', sheet " + Math.round(Equipment.look._y) + ".." + Math.round(Equipment.look._y + Equipment.number(Equipment.look.high) * Equipment.look._yscale / 100) + " at " + Math.round(Equipment.look._yscale) + "% bar " + Math.round(Equipment.barTop()) + ", text " + settings.nameText + "/" + settings.wordsText + "/" + settings.numbersText + "/" + settings.quietText + " card " + settings.cardText);
};
