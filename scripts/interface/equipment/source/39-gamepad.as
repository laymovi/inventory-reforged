Equipment.PAD_A = 276;
Equipment.PAD_B = 277;
Equipment.PAD_X = 278;
Equipment.PAD_Y = 279;
Equipment.PAD_STICK = 273;
Equipment.PAD_RING_GAP = 3;
Equipment.PAD_TURN_STEP = 15;
Equipment.PAD_UP_DOWN = [{name:"Up", context:1}, {name:"Down", context:1}];
Equipment.PAD_LEFT_RIGHT = [{name:"Left", context:1}, {name:"Right", context:1}];
Equipment.PAD_INSPECT_HINT = Equipment.say("Right stick to turn") + "     " + Equipment.say("Up and down to zoom") + "     " + Equipment.say("B to close");

// On a gamepad the click of the right stick, the game's item zoom, moves the input from the list to the panel and
// back, the way the favorites menu of SkyUI moves it with a button of its own. On the panel the pad walks the slots,
// A does what a click does, X works the eye, Y opens the sheet of the look, B steps back. The plugin tells of the click
// and of a hold, which opens the menu of a row on the list and inspects what's in focus on the panel, turns the doll and
// the inspected item with the right stick and scrolls long words with it up and down
Equipment.buildPad = function()
{
   var menu = Equipment.menu;
   Equipment.padFocus = undefined;
   Equipment.padLast = {kind:"slot", column:1, row:0};
   Equipment.padTurned = Equipment.PAD_TURNS_NOTHING;
   Equipment.padRing = Equipment.over.createEmptyMovieClip("equipmentPadRing", Equipment.over.getNextHighestDepth());
   Equipment.padRing.hitTestDisable = true;
   Equipment.wrapPadMenu(menu);
   Equipment.padBlock(menu, "DropItem");
   Equipment.padBlock(menu, "AttemptChargeItem");
   // the doll turns with the stick only while no window shows a model the stick turns already
   Equipment.padShowWindow = Equipment.showWindow;
   Equipment.showWindow = function()
   {
      Equipment.padShowWindow();
      Equipment.padTurns();
   };
   // the inspect view closes by B, the cross or the mouse as well as by the stick, the focus shows again after each
   Equipment.padLeaveInspect = Equipment.leaveInspect;
   Equipment.leaveInspect = function()
   {
      Equipment.padLeaveInspect();
      if(Equipment.padFocus != undefined)
      {
         Equipment.padMark();
         Equipment.padHints();
      }
      Equipment.padTurns();
   };
   // a new list can take a strip or a window away from under the focus and change what the buttons say, the magic
   // menu reads its slots from its own list. The sheet of the look gives the focus back to the panel when it shuts
   Equipment.padAfter("listReady");
   Equipment.padAfter("readMagic");
   Equipment.padAfter("closeLook");
   Equipment.padPlatform();
};

// A chest or a shop has no panel. A hold of the right stick on a row there opens its menu, the pad walks it as in the
// inventory, and a click zooms the item the game's way (padListStick)
Equipment.buildListPad = function()
{
   Equipment.padTurned = Equipment.PAD_TURNS_NOTHING;
   Equipment.wrapPadMenu(Equipment.menu);
   Equipment.padPlatform();
};

// What the pad needs of any item menu: the input goes to the pad first, the bar tells its words, the calls the game makes
// for the selected row wait while the panel or a row's menu holds the input, and the menu hears when a gamepad or the
// keyboard takes over
Equipment.wrapPadMenu = function(menu)
{
   Equipment.padBuilt = true;
   menu.padHandleInput = menu.handleInput;
   menu.handleInput = function(details, pathToFocus)
   {
      var taken = Equipment.chargeKey(details) || Equipment.padInput(details) || this.padHandleInput(details, pathToFocus);
      Equipment.padTurns();
      return taken;
   };
   // X takes all in a chest
   Equipment.padBlock(menu, "AttemptEquip");
   Equipment.padBlock(menu, "onXButtonPress");

   menu.padUpdateBottomBar = menu.updateBottomBar;
   menu.updateBottomBar = function(a_bSelected)
   {
      if(Equipment.padFocus != undefined)
      {
         Equipment.padHints();
         return undefined;
      }
      if(Equipment.padLine != undefined && Equipment.padMenuUp())
      {
         Equipment.padMenuHints();
         return undefined;
      }
      this.padUpdateBottomBar(a_bSelected);
      Equipment.padListHint();
   };
   // the menu of a row the pad walked gives the bar back to the list once it's gone
   Equipment.padCloseContext = Equipment.closeContext;
   Equipment.closeContext = function()
   {
      var walked = Equipment.padLine != undefined && Equipment.padMenuUp();
      Equipment.padCloseContext();
      if(walked)
      {
         Equipment.padLine = undefined;
         menu.updateBottomBar(menu.inventoryLists.itemList.selectedIndex >= 0);
      }
   };
   menu.padSetPlatform = menu.SetPlatform;
   menu.SetPlatform = function(a_platform, a_bPS3Switch)
   {
      this.padSetPlatform(a_platform, a_bPS3Switch);
      Equipment.padPlatform();
   };
};

Equipment.padAfter = function(name)
{
   var own = Equipment[name];
   if(own == undefined)
   {
      return undefined;
   }
   Equipment[name] = function()
   {
      own.apply(Equipment, arguments);
      if(Equipment.padFocus != undefined)
      {
         Equipment.padMark();
         Equipment.padHints();
      }
   };
};

// the menu's own call rides on the wrapper itself, see Equipment.cardInfoUnder for why it can't come from around it
Equipment.padBlock = function(menu, name)
{
   var blocked;
   if(menu[name] == undefined)
   {
      return undefined;
   }
   blocked = function()
   {
      if(!Equipment.padHolds())
      {
         arguments.callee.own.apply(this, arguments);
      }
   };
   blocked.own = menu[name];
   menu[name] = blocked;
};

// the panel, the inspect view or the menu of a row on the pad holds the input, the list under them stays as it was
Equipment.padHolds = function()
{
   return Equipment.padFocus != undefined || Equipment.inspecting || Equipment.padReady() && Equipment.padMenuUp();
};

Equipment.padMenuUp = function()
{
   return Equipment.context != undefined && Equipment.context._visible == true;
};

Equipment.padReady = function()
{
   return Equipment.padBuilt == true && Equipment.menu._platform != 0;
};

// SkyUI shows its zoom sign for the stick, the click of the stick belongs to the panel now. A chest's click still zooms
Equipment.padPlatform = function()
{
   var menu = Equipment.menu;
   var hint = Equipment.viewer.hint;
   var list = menu.inventoryLists.itemList;
   if(menu._platform == 0 && Equipment.padFocus != undefined)
   {
      Equipment.leavePad(false);
   }
   // the pointer lights the lines of a row's menu itself
   if(menu._platform == 0)
   {
      Equipment.padLightLine(undefined);
   }
   if(Equipment.panel != undefined)
   {
      menu.inventoryLists.zoomButtonHolder._visible = menu._platform == 0;
   }
   if(hint != undefined)
   {
      hint.text = menu._platform == 0 ? Equipment.INSPECT_HINT : Equipment.PAD_INSPECT_HINT;
      hint._x = Equipment.screenRect().x + (Equipment.screenRect().width - hint._width) / 2;
   }
   menu.updateBottomBar(list.selectedIndex >= 0);
};

// The plugin tells of a click of the stick, a hold says so. A hold on a row of the list opens the row's menu, a hold on
// the panel inspects. The magic menu has neither, a hold there is a click. The stick closes a row's menu and the sheet
// of the look as B does
Equipment.padStick = function(held)
{
   if(!Equipment.padReady())
   {
      return undefined;
   }
   if(Equipment.panel == undefined)
   {
      Equipment.padListStick(held);
      return undefined;
   }
   if(Equipment.inspecting)
   {
      Equipment.leaveInspect();
   }
   else if(Equipment.padMenuUp())
   {
      Equipment.closeContext();
   }
   else if(Equipment.lookOpen())
   {
      Equipment.closeLook();
      gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
   }
   else if(!Equipment.listsAnswer())
   {
      return undefined;
   }
   else if(held == true && Equipment.padFocus == undefined && Equipment.settings.rowMenu && Equipment.context != undefined)
   {
      Equipment.padRowMenu(Equipment.menu.inventoryLists.itemList.selectedEntry);
   }
   else if(held == true && Equipment.viewer != undefined)
   {
      Equipment.padInspect();
   }
   // the item browser stands where the slots are and has no pad walk of its own yet
   else if(Equipment.padFocus == undefined && !Equipment.browsing)
   {
      Equipment.enterPad();
   }
   else
   {
      Equipment.leavePad(true);
   }
   Equipment.padMark();
   Equipment.padTurns();
};

// In a chest or a shop a hold on a row opens its menu and the stick closes it again. A click zooms the item the game's
// way, in and back out, the plugin took the zoom key there to tell the two apart. A hold where no menu opens is a click
Equipment.padListStick = function(held)
{
   var plugin = Equipment.plugin();
   if(plugin == undefined)
   {
      return undefined;
   }
   if(plugin.Zoomed() == true)
   {
      plugin.GameZoom();
   }
   else if(Equipment.padMenuUp())
   {
      Equipment.closeContext();
      gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
   }
   else if(!(held == true && Equipment.settings.rowMenu && Equipment.listsAnswer() && Equipment.padRowMenu(Equipment.menu.inventoryLists.itemList.selectedEntry)))
   {
      plugin.GameZoom();
   }
};

// the strip goes in while an item is inspected, the focus waits on its slot
Equipment.padInspect = function()
{
   var on = Equipment.padFocus != undefined;
   var cell = on ? Equipment.padTarget() : undefined;
   var entry = on && cell != undefined ? cell.entries[0] : Equipment.menu.inventoryLists.itemList.selectedEntry;
   if(on && cell == undefined || Equipment.viewer == undefined)
   {
      return undefined;
   }
   if(on && cell.taken)
   {
      entry = Equipment.slotNamed("right").entries[0];
   }
   if(entry != undefined && Equipment.inspectEntry(entry) && on)
   {
      Equipment.padFocus = Equipment.padFocusOf(Equipment.ownerOf(cell));
   }
};

// The row the list was on is kept for the way back, the window of a row goes while the panel has the input
Equipment.enterPad = function()
{
   var list = Equipment.menu.inventoryLists.itemList;
   Equipment.padKept = list.selectedIndex;
   Equipment.closeContext();
   Equipment.closePopup();
   Equipment.padFocus = Equipment.padStart(list.selectedEntry);
   Equipment.padLast = Equipment.padFocus;
   list.selectedIndex = -1;
   Equipment.padMark();
   Equipment.padHints();
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

// the slot of the selected row's kind, the last one in focus otherwise
Equipment.padStart = function(entry)
{
   var slot = entry != undefined ? Equipment.slotOf(entry) : undefined;
   if(slot != undefined && Equipment.slotShown(slot))
   {
      return {kind:"slot", column:slot.column, row:slot.row};
   }
   return {kind:"slot", column:Equipment.padLast.column, row:Equipment.padLast.row};
};

// Back on the list the row it was on is selected again, if the list still shows it. A row the panel found in the
// list stays, that was the point of finding it
Equipment.leavePad = function(sound)
{
   var list = Equipment.menu.inventoryLists.itemList;
   var kept = Equipment.padKept;
   if(Equipment.padFocus == undefined)
   {
      return undefined;
   }
   Equipment.padUnmark();
   Equipment.padFocus = undefined;
   Equipment.padKept = undefined;
   Equipment.closePopup();
   Equipment.closePieces();
   if(list.selectedIndex < 0 && kept != undefined && kept >= 0 && list.getListEnumIndex(kept) != undefined)
   {
      list.selectedIndex = kept;
   }
   Equipment.menu.updateBottomBar(list.selectedIndex >= 0);
   Equipment.padTurns();
   if(sound)
   {
      gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
   }
};

// Up, down, left and right walk the panel, A presses, B steps back, X works the eye. A held button repeats, only
// its press counts, and its repeats are kept from the list after it left the panel. True when the panel took it
Equipment.padInput = function(details)
{
   var nav = details.navEquivalent;
   var code = details.skseKeycode;
   var button;
   if(!Equipment.padReady())
   {
      return false;
   }
   if(Equipment.padEating != undefined && nav == Equipment.padEating.nav && code == Equipment.padEating.code)
   {
      if(details.value != "keyDown")
      {
         if(details.value == "keyUp")
         {
            Equipment.padEating = undefined;
         }
         return true;
      }
      // a new press of it, its let go was never seen
      Equipment.padEating = undefined;
   }
   if(!Shared.GlobalFunc.IsKeyPressed(details))
   {
      return false;
   }
   if(Equipment.inspecting)
   {
      // B closes the view the usual way, held on it mustn't go on to close the menu
      if(details.value == "keyDown" && Equipment.padButton(nav, code) == "back")
      {
         Equipment.padEating = {nav:nav, code:code};
      }
      return Equipment.padInspectInput(nav);
   }
   if(Equipment.padMenuUp())
   {
      return Equipment.padMenuInput(details, nav, code);
   }
   if(Equipment.padFocus == undefined)
   {
      return false;
   }
   // the sheet holds the rows itself while it's up, the list answers nothing then
   if(Equipment.lookOpen())
   {
      return Equipment.padLookInput(details, nav, code);
   }
   // a dialog of SkyUI over the lists, the column one on a hold of the left stick, takes the pad while it's up
   if(!Equipment.listsAnswer())
   {
      return false;
   }
   Equipment.padSettle();
   if(Equipment.padWay(nav) != undefined)
   {
      Equipment.padMove(Equipment.padWay(nav));
      return true;
   }
   button = Equipment.padButton(nav, code);
   // Y is the sheet's only where the menu has one
   if(button == undefined || button == "look" && !Equipment.padLookReady())
   {
      return false;
   }
   Equipment.padEating = {nav:nav, code:code};
   if(details.value != "keyDown")
   {
      return true;
   }
   if(button == "press")
   {
      Equipment.padPress();
   }
   else if(button == "back")
   {
      Equipment.padBack();
   }
   else if(button == "look")
   {
      Equipment.padOpenLook();
   }
   else
   {
      Equipment.padHide();
   }
   return true;
};

Equipment.padWay = function(nav)
{
   var codes = gfx.ui.NavigationCode;
   switch(nav)
   {
      case codes.UP:
         return "up";
      case codes.DOWN:
         return "down";
      case codes.LEFT:
         return "left";
      case codes.RIGHT:
         return "right";
   }
   return undefined;
};

// B comes as Tab or as Escape, whichever way the game sends it
Equipment.padButton = function(nav, code)
{
   var codes = gfx.ui.NavigationCode;
   if(nav == codes.ENTER || code == Equipment.PAD_A)
   {
      return "press";
   }
   if(nav == codes.TAB || nav == codes.SHIFT_TAB || nav == codes.ESCAPE || code == Equipment.PAD_B)
   {
      return "back";
   }
   if(code == Equipment.PAD_X)
   {
      return "hide";
   }
   if(code == Equipment.PAD_Y)
   {
      return "look";
   }
   return undefined;
};

// in the inspect view up and down bring the item closer, left and right turn it by a step
Equipment.padInspectInput = function(nav)
{
   var way = Equipment.padWay(nav);
   if(way == undefined || Equipment.plugin() == undefined)
   {
      return false;
   }
   if(way == "up" || way == "down")
   {
      Equipment.plugin().InspectZoom(way == "up" ? Equipment.INSPECT_ZOOM : 1 / Equipment.INSPECT_ZOOM);
   }
   else
   {
      Equipment.plugin().InspectTurn(way == "left" ? -Equipment.PAD_TURN_STEP : Equipment.PAD_TURN_STEP, 0);
   }
   return true;
};

// The menu of a row opens on a hold of the stick at the row past its name, the pointer may stand anywhere while a pad
// plays. Its first line lights up and the bar tells A and B
Equipment.padRowMenu = function(entry)
{
   if(!Equipment.openRowMenu(entry))
   {
      return false;
   }
   Equipment.padPlaceMenu(entry);
   Equipment.padLightLine(0);
   Equipment.padMenuHints();
   return true;
};

// at the top of the row, its copy over the 3D goes along. Without one the model of the row's window steps out when
// the menu lies over the window there
Equipment.padPlaceMenu = function(entry)
{
   var context = Equipment.context;
   var list = Equipment.menu.inventoryLists.itemList;
   var row = entry.clipIndex != undefined ? list.getClipByIndex(entry.clipIndex) : undefined;
   var point = {x:0, y:0};
   var hides;
   if(row == undefined || row.itemIndex != entry.itemIndex)
   {
      return undefined;
   }
   row.localToGlobal(point);
   Equipment.toPanel(point);
   context._x = Equipment.contextLeft(point.x, context.wide, undefined, entry);
   context._y = Math.min(point.y, Equipment.barTop() - Equipment.MARGIN - context.high);
   if(Equipment.contextOverlaid)
   {
      Equipment.overlayContext();
   }
   Equipment.coverWindow();
   hides = Equipment.contextOverWindow() && !Equipment.contextOverlaid && Equipment.plugin() != undefined;
   if(hides != (Equipment.contextHidesModel == true))
   {
      Equipment.contextHidesModel = hides;
      Equipment.plugin().ShowPreview(Equipment.previewShown());
   }
};

// the lines of the open menu top to bottom, a divider is no clip
Equipment.padLines = function()
{
   var context = Equipment.context;
   var lines = [];
   for(var name in context)
   {
      if(context[name] instanceof MovieClip && context[name].what != undefined)
      {
         lines.push(context[name]);
      }
   }
   lines.sort(function(a, b)
   {
      return a._y - b._y;
   });
   return lines;
};

// one line lit as under the pointer, none for undefined
Equipment.padLightLine = function(index)
{
   var lines = Equipment.padMenuUp() ? Equipment.padLines() : [];
   if(Equipment.padLine != undefined && lines[Equipment.padLine] != undefined)
   {
      Equipment.drawContextLine(lines[Equipment.padLine], false);
   }
   Equipment.padLine = index != undefined && lines.length > 0 ? Math.max(0, Math.min(lines.length - 1, index)) : undefined;
   if(Equipment.padLine != undefined)
   {
      Equipment.drawContextLine(lines[Equipment.padLine], true);
   }
};

// Up and down walk the lines of the open menu, A presses the lit one, B closes the menu. Left and right do nothing
// while it's up, the list keeps its category. B held after it closed the menu is kept from the list
Equipment.padMenuInput = function(details, nav, code)
{
   var way = Equipment.padWay(nav);
   var button = Equipment.padButton(nav, code);
   var at = Equipment.padLine;
   if(way == "up" || way == "down")
   {
      Equipment.padLightLine(at == undefined ? 0 : at + (way == "up" ? -1 : 1));
      if(Equipment.padLine != at)
      {
         gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
      }
      Equipment.padMenuHints();
      return true;
   }
   if(way != undefined)
   {
      return true;
   }
   if(button == undefined)
   {
      return false;
   }
   Equipment.padEating = {nav:nav, code:code};
   if(details.value != "keyDown")
   {
      return true;
   }
   if(button == "press" && at != undefined)
   {
      Equipment.padLines()[at].onPress();
   }
   else if(button == "press")
   {
      Equipment.padLightLine(0);
      Equipment.padMenuHints();
   }
   else if(button == "back")
   {
      Equipment.closeContext();
      gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
   }
   return true;
};

Equipment.padMenuHints = function()
{
   var menu = Equipment.menu;
   var panel = menu.navPanel;
   panel.clearButtons();
   panel.addButton({text:Equipment.say("Choose"), controls:menu._acceptControls});
   panel.addButton({text:Equipment.say("Back"), controls:menu._cancelControls});
   panel.updateButtons(true);
};

// What lies around the focus now, for padNext
Equipment.padWorld = function()
{
   var strip = Equipment.pieceStrip;
   var chips = Equipment.padChips();
   var people = Equipment.padPeople();
   var world = {rows:Equipment.ROWS, chips:chips.length, chipStart:0, people:people.length, personStart:0, hero:Equipment.hero._visible == true, heroOpen:Equipment.hero.high > 0, last:Equipment.padLast, gone:[]};
   var cell;
   var i = 0;
   while(i < chips.length && !chips[i].chosen)
   {
      i++;
   }
   world.chipStart = i < chips.length ? i : 0;
   i = 0;
   while(i < people.length && !people[i].shown)
   {
      i++;
   }
   world.personStart = i < people.length ? i : 0;
   // a slot the player took off the panel is gone, so is a place with no slot at all, the magic menu has three
   i = 0;
   while(i < 2 * Equipment.ROWS)
   {
      cell = Equipment.padCell({kind:"slot", column:i % 2, row:Math.floor(i / 2)});
      if(cell == undefined || !Equipment.slotShown(cell))
      {
         world.gone.push(i % 2 + "," + Math.floor(i / 2));
      }
      i++;
   }
   if(strip != undefined)
   {
      world.strip = {column:strip.slot.column, row:strip.slot.row, cells:strip.minis.length + 1};
   }
   if(Equipment.anchorSlot != undefined)
   {
      world.actions = Equipment.padActions().length;
      world.anchor = Equipment.padFocusOf(Equipment.anchorSlot);
   }
   return world;
};

// Where a move goes from a focus. The two columns of slots face each other across the doll, a strip that's out
// lies between its slot and the doll, the tabs of the companions lie above the top row, the subcategories above
// them, and the drawer under the bottom row. The buttons of an open slot window go left and right, up and down
// leave the window as they leave its slot. The drawer when out scrolls with up and down. A slot the player took off
// the panel is passed over
Equipment.padNext = function(at, way, world)
{
   var inward;
   var row;
   switch(at.kind)
   {
      case "slot":
         inward = at.column == 0 ? "right" : "left";
         if(way == "up" || way == "down")
         {
            row = Equipment.padRowFrom(world, at.column, at.row, way == "up" ? -1 : 1);
            if(row != undefined)
            {
               return {kind:"slot", column:at.column, row:row};
            }
            if(way == "up")
            {
               return Equipment.padAbove(world, at);
            }
            return world.hero ? {kind:"hero"} : at;
         }
         if(way != inward)
         {
            return at;
         }
         if(world.strip != undefined && world.strip.column == at.column && world.strip.row == at.row)
         {
            return {kind:"mini", cell:0};
         }
         row = Equipment.padNearRow(world, 1 - at.column, at.row);
         return row != undefined ? {kind:"slot", column:1 - at.column, row:row} : at;
      case "mini":
         inward = world.strip.column == 0 ? "right" : "left";
         if(way == "up" || way == "down")
         {
            return Equipment.padNext({kind:"slot", column:world.strip.column, row:world.strip.row}, way, world);
         }
         if(way == inward)
         {
            return at.cell < world.strip.cells - 1 ? {kind:"mini", cell:at.cell + 1} : at;
         }
         return at.cell > 0 ? {kind:"mini", cell:at.cell - 1} : {kind:"slot", column:world.strip.column, row:world.strip.row};
      case "chip":
         if(way == "left" || way == "right")
         {
            return {kind:"chip", index:Math.max(0, Math.min(world.chips - 1, at.index + (way == "left" ? -1 : 1)))};
         }
         if(way == "down")
         {
            return world.people > 0 ? {kind:"person", index:world.personStart} : Equipment.padSlotNear(world, world.last.column, 0, at);
         }
         return at;
      case "person":
         if(way == "left" || way == "right")
         {
            return {kind:"person", index:Math.max(0, Math.min(world.people - 1, at.index + (way == "left" ? -1 : 1)))};
         }
         if(way == "up")
         {
            return world.chips > 0 ? {kind:"chip", index:world.chipStart} : at;
         }
         return Equipment.padSlotNear(world, world.last.column, 0, at);
      case "hero":
         if(way == "left" || way == "right")
         {
            return Equipment.padSlotNear(world, way == "left" ? 0 : 1, world.rows - 1, at);
         }
         if(world.heroOpen)
         {
            return {kind:"hero", scroll:way == "up" ? -1 : 1};
         }
         return way == "up" ? Equipment.padSlotNear(world, world.last.column, world.rows - 1, at) : at;
      case "action":
         if(way == "left" || way == "right")
         {
            return {kind:"action", index:Math.max(0, Math.min(world.actions - 1, at.index + (way == "left" ? -1 : 1)))};
         }
         return Equipment.padNext(world.anchor, way, world);
   }
   return at;
};

// up from the top row: the companions' tabs, the subcategories past them
Equipment.padAbove = function(world, at)
{
   if(world.people > 0)
   {
      return {kind:"person", index:world.personStart};
   }
   return world.chips > 0 ? {kind:"chip", index:world.chipStart} : at;
};

// whether the slot at a place of the two columns is still on the panel
Equipment.padShownAt = function(world, column, row)
{
   return world.gone == undefined || !Equipment.has(world.gone, column + "," + row);
};

// the next row up or down a column that's on the panel, nothing past the end of the column
Equipment.padRowFrom = function(world, column, row, step)
{
   var at = row + step;
   while(at >= 0 && at < world.rows)
   {
      if(Equipment.padShownAt(world, column, at))
      {
         return at;
      }
      at += step;
   }
   return undefined;
};

// the row of a column nearest to a row that's on the panel, the upper one of two as near
Equipment.padNearRow = function(world, column, row)
{
   var away = 0;
   while(away < world.rows)
   {
      if(row - away >= 0 && Equipment.padShownAt(world, column, row - away))
      {
         return row - away;
      }
      if(row + away < world.rows && Equipment.padShownAt(world, column, row + away))
      {
         return row + away;
      }
      away++;
   }
   return undefined;
};

// the slot of a column nearest a row, of the other column when the player took this one off the panel whole
Equipment.padSlotNear = function(world, column, row, otherwise)
{
   var near = Equipment.padNearRow(world, column, row);
   if(near != undefined)
   {
      return {kind:"slot", column:column, row:near};
   }
   near = Equipment.padNearRow(world, 1 - column, row);
   return near != undefined ? {kind:"slot", column:1 - column, row:near} : otherwise;
};

Equipment.padSame = function(a, b)
{
   return a.kind == b.kind && a.column == b.column && a.row == b.row && a.cell == b.cell && a.index == b.index;
};

Equipment.padMove = function(way)
{
   var next = Equipment.padNext(Equipment.padFocus, way, Equipment.padWorld());
   if(next.scroll != undefined)
   {
      Equipment.scrollHero(next.scroll * Equipment.HERO_WHEEL);
      return undefined;
   }
   if(!Equipment.padSame(next, Equipment.padFocus))
   {
      Equipment.padGo(next);
      gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
   }
};

// A window of a slot goes when the focus leaves its buttons, a strip when the focus leaves it, its slot and the
// window of one of its pieces
Equipment.padGo = function(next)
{
   var strip = Equipment.pieceStrip;
   Equipment.padUnmark();
   if(next.kind != "action")
   {
      Equipment.closePopup();
   }
   if(strip != undefined && next.kind != "mini" && next.kind != "action" && !(next.kind == "slot" && next.column == strip.slot.column && next.row == strip.slot.row))
   {
      Equipment.closePieces();
   }
   Equipment.padFocus = next;
   if(next.kind == "slot")
   {
      Equipment.padLast = next;
   }
   Equipment.padShowMini();
   Equipment.padMark();
   Equipment.padHints();
};

// A strip, a window or the drawer can go away from under the focus, the list was made anew or an item got
// inspected. The focus then goes back to the last slot it was on, a subcategory past the end to the last one
Equipment.padSettle = function()
{
   var at = Equipment.padFocus;
   var strip = Equipment.pieceStrip;
   var count;
   var stale = false;
   if(at == undefined)
   {
      return undefined;
   }
   switch(at.kind)
   {
      case "mini":
         stale = strip == undefined;
         if(!stale)
         {
            at.cell = Math.min(at.cell, strip.minis.length);
         }
         break;
      case "action":
         count = Equipment.padActions().length;
         stale = Equipment.anchorSlot == undefined || count == 0;
         at.index = Math.min(at.index, count - 1);
         break;
      case "chip":
         count = Equipment.padChips().length;
         stale = count == 0;
         at.index = Math.min(at.index, count - 1);
         break;
      case "person":
         count = Equipment.padPeople().length;
         stale = count == 0;
         at.index = Math.min(at.index, count - 1);
         break;
      case "hero":
         stale = !Equipment.hero._visible;
   }
   if(stale)
   {
      Equipment.padFocus = {kind:"slot", column:Equipment.padLast.column, row:Equipment.padLast.row};
   }
   // a slot the player took off the panel hands the focus to the nearest one still on it
   at = Equipment.padFocus;
   if(at.kind == "slot" && !Equipment.slotShown(Equipment.padCell(at)))
   {
      Equipment.padFocus = Equipment.padSlotNear(Equipment.padWorld(), at.column, at.row, at);
   }
};

// a piece walked to past the end of the strip in sight scrolls the strip
Equipment.padShowMini = function()
{
   var strip = Equipment.pieceStrip;
   var at = Equipment.padFocus;
   var piece;
   if(at.kind != "mini" || strip == undefined || at.cell == 0 || !strip.scrolls)
   {
      return undefined;
   }
   piece = at.cell - 1;
   if(piece < strip.first)
   {
      Equipment.scrollPieces(piece - strip.first);
   }
   else if(piece >= strip.first + strip.shown)
   {
      Equipment.scrollPieces(piece - strip.first - strip.shown + 1);
   }
};

// the slot or the small slot a focus stands for, nothing for a chip, a tab, the drawer and a button
Equipment.padCell = function(at)
{
   var strip = Equipment.pieceStrip;
   var i = 0;
   if(at.kind == "mini")
   {
      return strip == undefined ? undefined : (at.cell == 0 ? strip.plus : strip.minis[at.cell - 1]);
   }
   if(at.kind != "slot")
   {
      return undefined;
   }
   while(i < Equipment.SLOTS.length)
   {
      if(Equipment.SLOTS[i].column == at.column && Equipment.SLOTS[i].row == at.row)
      {
         return Equipment.SLOTS[i];
      }
      i++;
   }
   return undefined;
};

// the cell X and the hold of the stick act on: the focused one, the slot of an open window on its buttons
Equipment.padTarget = function()
{
   var at = Equipment.padFocus;
   return at.kind == "action" ? Equipment.anchorSlot : Equipment.padCell(at);
};

Equipment.padFocusOf = function(cell)
{
   var strip = Equipment.pieceStrip;
   var i = 0;
   if(cell.parent == undefined)
   {
      return {kind:"slot", column:cell.column, row:cell.row};
   }
   if(cell.plus)
   {
      return {kind:"mini", cell:0};
   }
   while(strip != undefined && i < strip.minis.length && strip.minis[i] != cell)
   {
      i++;
   }
   return {kind:"mini", cell:i + 1};
};

// the subcategories of the strip under the category bar in their order on screen
Equipment.padChips = function()
{
   var chips = [];
   for(var name in Equipment.chips)
   {
      if(Equipment.chips[name] instanceof MovieClip && Equipment.chips[name].row != undefined)
      {
         chips.push(Equipment.chips[name]);
      }
   }
   // a strip of a group a line reads line by line
   chips.sort(function(a, b)
   {
      return a._y != b._y ? a._y - b._y : a._x - b._x;
   });
   return chips;
};

// the tabs of the player and the companions over the doll, the ones the row had room for
Equipment.padPeople = function()
{
   var strip = Equipment.companions;
   var tabs = [];
   var i = 0;
   while(strip != undefined && strip._visible && strip["tab" + i] != undefined)
   {
      if(strip["tab" + i]._visible)
      {
         tabs.push(strip["tab" + i]);
      }
      i++;
   }
   return tabs;
};

Equipment.padActions = function()
{
   var actions = [];
   while(Equipment.actions["action" + actions.length] != undefined)
   {
      actions.push(Equipment.actions["action" + actions.length]);
   }
   return actions;
};

Equipment.padPress = function()
{
   var at = Equipment.padFocus;
   var cell = Equipment.padCell(at);
   if(!Equipment.listsAnswer())
   {
      return undefined;
   }
   switch(at.kind)
   {
      case "slot":
         // a slot of several pieces opens their strip, its first piece in focus
         if(Equipment.hasPieces(cell))
         {
            if(Equipment.pieceStrip == undefined || Equipment.pieceStrip.slot != cell)
            {
               Equipment.openPieces(cell);
            }
            Equipment.padGo({kind:"mini", cell:1});
            return undefined;
         }
         Equipment.padPressCell(cell);
         break;
      case "mini":
         Equipment.padPressCell(cell);
         break;
      case "chip":
         Equipment.pressChip(Equipment.padChips()[at.index]);
         break;
      case "person":
         // the menu closes and the one of that person opens
         if(Equipment.padPeople()[at.index] != undefined)
         {
            Equipment.switchCompanion(Equipment.padPeople()[at.index].person);
         }
         break;
      case "hero":
         Equipment.padHero();
         break;
      case "action":
         Equipment.padAction(at.index);
         return undefined;
   }
   Equipment.padMark();
   Equipment.padHints();
};

// a press on a cell as a single click does it, the window it opens takes the focus on its first button
Equipment.padPressCell = function(cell)
{
   if(cell.plus)
   {
      Equipment.closePopup();
      Equipment.filterSlot(cell.parent);
   }
   else
   {
      Equipment.press(cell);
   }
   if(Equipment.anchorSlot != undefined && Equipment.padActions().length > 0)
   {
      Equipment.padGo({kind:"action", index:0});
   }
};

// A button of the slot window. One that closes the window gives the focus back to its slot
Equipment.padAction = function(index)
{
   var button = Equipment.padActions()[index];
   var slot = Equipment.anchorSlot;
   var back = Equipment.padFocusOf(slot);
   if(button == undefined)
   {
      return undefined;
   }
   Equipment.padUnmark();
   Equipment.act(button.action.key, slot);
   // the strip goes in while an item is inspected, the focus waits on its slot
   if(Equipment.inspecting)
   {
      Equipment.padFocus = Equipment.padFocusOf(Equipment.ownerOf(slot));
   }
   else if(Equipment.anchorSlot == undefined || Equipment.padActions().length == 0)
   {
      Equipment.padFocus = back;
   }
   else
   {
      Equipment.padFocus = {kind:"action", index:Math.min(index, Equipment.padActions().length - 1)};
   }
   Equipment.padMark();
   Equipment.padHints();
};

// the drawer goes out as far as it was left or back in, like a click on its tab
Equipment.padHero = function()
{
   var state = Equipment.heroState;
   state.open = !state.open;
   if(state.open)
   {
      Equipment.closePieces();
      Equipment.showHero();
   }
   else
   {
      Equipment.drawHero(0);
   }
   Equipment.keepHero();
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

// X is the eye of the cell in focus
Equipment.padHide = function()
{
   var cell = Equipment.padTarget();
   if(cell == undefined || !Equipment.canToggle(cell))
   {
      return undefined;
   }
   if(Equipment.anchorSlot == cell)
   {
      Equipment.act("hide", cell);
   }
   else
   {
      Equipment.toggleHidden(cell);
   }
   Equipment.padMark();
   Equipment.padHints();
};

Equipment.padBack = function()
{
   var at = Equipment.padFocus;
   var strip = Equipment.pieceStrip;
   if(at.kind == "action" && Equipment.anchorSlot != undefined)
   {
      Equipment.padUnmark();
      Equipment.padFocus = Equipment.padFocusOf(Equipment.anchorSlot);
      Equipment.closePopup();
   }
   else if(at.kind == "mini" && strip != undefined)
   {
      Equipment.padGo({kind:"slot", column:strip.slot.column, row:strip.slot.row});
      Equipment.closePieces();
   }
   else
   {
      Equipment.leavePad(true);
      return undefined;
   }
   Equipment.padMark();
   Equipment.padHints();
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

// The focus looks like the pointer resting there, with a gold ring around a slot, a subcategory or a companion's tab
// so it reads from the couch. The tab of the drawer and the buttons of a window light up as under the pointer
Equipment.padMark = function()
{
   var at;
   var ring = Equipment.padRing;
   var cell;
   var size;
   var chip;
   var tab;
   Equipment.padUnmark();
   Equipment.padSettle();
   at = Equipment.padFocus;
   ring.clear();
   if(at == undefined || Equipment.inspecting)
   {
      return undefined;
   }
   if(Equipment.lookOpen())
   {
      Equipment.padLookMark();
      return undefined;
   }
   if(at.kind == "slot" || at.kind == "mini")
   {
      cell = Equipment.padCell(at);
      if(cell == undefined)
      {
         return undefined;
      }
      size = Equipment.cellSize(cell);
      Equipment.hover(cell, true);
      Equipment.padRingAround(cell.box, size, size);
      Equipment.padMarked = {cell:cell};
   }
   else if(at.kind == "chip")
   {
      chip = Equipment.padChips()[at.index];
      if(chip == undefined)
      {
         return undefined;
      }
      Equipment.drawChip(chip, true);
      Equipment.padRingAround(chip, chip.wide, Equipment.STRIP_HIGH);
      Equipment.padMarked = {chip:chip};
   }
   else if(at.kind == "person")
   {
      tab = Equipment.padPeople()[at.index];
      if(tab == undefined)
      {
         return undefined;
      }
      tab.lit = true;
      Equipment.drawCompanionTab(tab);
      Equipment.padRingAround(tab, tab.wide, Equipment.HERO_TAB_HIGH);
      Equipment.padMarked = {person:tab};
   }
   else if(at.kind == "hero")
   {
      Equipment.hero.tab.lit = true;
      Equipment.drawHeroTab();
      Equipment.padMarked = {tab:Equipment.hero.tab};
   }
   else if(Equipment.padActions()[at.index] != undefined)
   {
      Equipment.padMarked = {button:Equipment.padActions()[at.index]};
      Equipment.padMarked.button.lit = true;
      Equipment.drawAction(Equipment.padMarked.button);
   }
};

Equipment.padUnmark = function()
{
   var marked = Equipment.padMarked;
   Equipment.padMarked = undefined;
   Equipment.padRing.clear();
   if(marked == undefined)
   {
      return undefined;
   }
   if(marked.cell != undefined)
   {
      Equipment.hover(marked.cell, false);
   }
   else if(marked.chip != undefined)
   {
      Equipment.drawChip(marked.chip, false);
   }
   else if(marked.person != undefined)
   {
      marked.person.lit = false;
      Equipment.drawCompanionTab(marked.person);
   }
   else if(marked.tab != undefined)
   {
      marked.tab.lit = false;
      Equipment.drawHeroTab();
   }
   else if(marked.look != undefined)
   {
      Equipment.padLightLook(marked.look, false);
   }
   else
   {
      marked.button.lit = false;
      Equipment.drawAction(marked.button);
   }
};

// a rounded gold line a little outside a box of a clip, in the panel's units
Equipment.padRingAround = function(clip, wide, high)
{
   var gap = Equipment.PAD_RING_GAP;
   var from = {x:0, y:0};
   var to = {x:wide, y:high};
   var ring = Equipment.padRing;
   clip.localToGlobal(from);
   clip.localToGlobal(to);
   Equipment.toPanel(from);
   Equipment.toPanel(to);
   ring.lineStyle(2, Equipment.GOLD, 90, true);
   Equipment.roundBox(ring, from.x - gap, from.y - gap, to.x - from.x + 2 * gap, to.y - from.y + 2 * gap, 6);
   ring.lineStyle();
};

// The bottom bar on the panel: what A does in focus, the eye, the sheet of the look, scrolling the drawer, the way back
// and the way to the list
Equipment.padHints = function()
{
   var menu = Equipment.menu;
   var panel = menu.navPanel;
   var at = Equipment.padFocus;
   var press;
   var hide;
   if(Equipment.lookOpen())
   {
      Equipment.padLookHints();
      return undefined;
   }
   press = Equipment.padPressWords(at);
   hide = Equipment.padHideWords();
   panel.clearButtons();
   if(press != undefined)
   {
      panel.addButton({text:press, controls:menu._acceptControls});
   }
   if(hide != undefined)
   {
      panel.addButton({text:hide, controls:skyui.defines.Input.XButton});
   }
   if(Equipment.padLookReady())
   {
      panel.addButton({text:Equipment.say("Look"), controls:skyui.defines.Input.YButton});
   }
   if(at.kind == "hero" && Equipment.hero.high > 0)
   {
      panel.addButton({text:Equipment.say("Scroll"), controls:Equipment.PAD_UP_DOWN});
   }
   panel.addButton({text:Equipment.say("Back"), controls:menu._cancelControls});
   panel.addButton({text:Equipment.say("List"), controls:{keyCode:Equipment.PAD_STICK}});
   if(Equipment.padTarget() != undefined && Equipment.padInspectable(Equipment.padTarget().entries[0]))
   {
      panel.addButton({text:Equipment.say("Inspect (hold)"), controls:{keyCode:Equipment.PAD_STICK}});
   }
   panel.updateButtons(true);
};

// On the list SkyUI's own buttons and the way to the panel, with a row selected the hold that opens its menu, or
// inspects it with the row menu switched off. That's six at most, as many as the bar holds
Equipment.padListHint = function()
{
   var panel = Equipment.menu.navPanel;
   var entry = Equipment.menu.inventoryLists.itemList.selectedEntry;
   if(!Equipment.padReady() || Equipment.inspecting)
   {
      return undefined;
   }
   if(Equipment.panel != undefined && !Equipment.browsing)
   {
      panel.addButton({text:Equipment.say("Panel"), controls:{keyCode:Equipment.PAD_STICK}});
   }
   if(entry != undefined && Equipment.settings.rowMenu && Equipment.context != undefined)
   {
      panel.addButton({text:Equipment.say("Menu (hold)"), controls:{keyCode:Equipment.PAD_STICK}});
   }
   else if(Equipment.padInspectable(entry))
   {
      panel.addButton({text:Equipment.say("Inspect (hold)"), controls:{keyCode:Equipment.PAD_STICK}});
   }
   panel.updateButtons(true);
};

// the hold inspects only in a menu with the inspect view, the magic menu has none
Equipment.padInspectable = function(entry)
{
   return Equipment.viewer != undefined && Equipment.inspectable(entry);
};

Equipment.padPressWords = function(at)
{
   var cell = Equipment.padCell(at);
   var chip;
   var tab;
   var button;
   switch(at.kind)
   {
      case "slot":
      case "mini":
         if(cell == undefined)
         {
            return undefined;
         }
         if(Equipment.hasPieces(cell))
         {
            return Equipment.say("Pieces");
         }
         if(cell.plus || cell.entries.length == 0 || Equipment.isSpell(cell.entries[0]))
         {
            return Equipment.activeSlot == Equipment.ownerOf(cell) ? Equipment.say("Show everything") : Equipment.say("Show what fits");
         }
         // a row the list doesn't show opens the window of the slot all the same
         return Equipment.settings.popup || !Equipment.listShows(cell.entries[0]) ? Equipment.say("Details") : Equipment.say("Find in list");
      case "chip":
         chip = Equipment.padChips()[at.index];
         return chip == undefined ? undefined : (chip.row < 0 ? Equipment.say("Show everything") : (chip.chosen ? Equipment.say("Clear") : Equipment.say("Choose")));
      case "person":
         tab = Equipment.padPeople()[at.index];
         return tab == undefined || tab.shown ? undefined : Equipment.say("Open");
      case "hero":
         return Equipment.hero.high > 0 ? Equipment.say("Close") : Equipment.say("Open");
      case "action":
         button = Equipment.padActions()[at.index];
         return button == undefined ? undefined : button.action.words;
   }
   return undefined;
};

Equipment.padHideWords = function()
{
   var cell = Equipment.padTarget();
   if(cell == undefined || !Equipment.canToggle(cell))
   {
      return undefined;
   }
   return Equipment.looksHidden(cell) ? Equipment.say("Show") : Equipment.say("Hide");
};

// the sheet of the look opens on the pad where its button is up, the plugin draws what it sets
Equipment.padLookReady = function()
{
   return Equipment.look != undefined && Equipment.lookButton._visible == true;
};

// Y on the panel opens the sheet of the look, with the part last in focus there, the first line under the tabs at first
Equipment.padOpenLook = function()
{
   if(!Equipment.padLookReady() || !Equipment.listsAnswer())
   {
      return undefined;
   }
   Equipment.padUnmark();
   Equipment.openLook();
   if(Equipment.padLookAt == undefined)
   {
      Equipment.padLookAt = 2;
   }
   Equipment.padMark();
   Equipment.padHints();
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

// Up and down walk the lines of the sheet, left and right step the value between arrows or go to the part beside, A
// ticks, turns the page or resets, B, Y and the stick close the sheet. A held way repeats, a button counts on its press
Equipment.padLookInput = function(details, nav, code)
{
   var way = Equipment.padWay(nav);
   var button = Equipment.padButton(nav, code);
   if(way != undefined)
   {
      Equipment.padLookMove(way);
      return true;
   }
   if(button == undefined)
   {
      return false;
   }
   Equipment.padEating = {nav:nav, code:code};
   if(details.value != "keyDown")
   {
      return true;
   }
   if(button == "press")
   {
      Equipment.padLookPress();
   }
   else if(button == "back" || button == "look")
   {
      Equipment.closeLook();
      gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
   }
   return true;
};

Equipment.padLookMove = function(way)
{
   var lines = Equipment.look.lines;
   var at = lines[Equipment.padLookAt];
   var next;
   var boxes = [];
   var i = 0;
   if(at != undefined && at.less != undefined && (way == "left" || way == "right"))
   {
      Equipment.stepLook(at.key, way == "left" ? -1 : 1);
      Equipment.padMark();
      return undefined;
   }
   while(i < lines.length)
   {
      boxes.push({x:lines[i]._x, y:lines[i]._y, wide:lines[i].wide, high:lines[i].high});
      i++;
   }
   next = Equipment.padLookNext(boxes, Equipment.padLookAt, way);
   if(next == undefined)
   {
      return undefined;
   }
   Equipment.padUnmark();
   Equipment.padLookAt = next;
   Equipment.padMark();
   Equipment.padHints();
   gfx.io.GameDelegate.call("PlaySound", ["UIMenuFocus"]);
};

// Where a move goes on the sheet, boxes of its parts in its own units. Up and down go to the nearest line above or below,
// to its part whose left edge is nearest, so a line across the sheet leads to the left column. Left and right go to the
// nearest part beside in the same line. Nothing past the edges
Equipment.padLookNext = function(boxes, from, way)
{
   var at = boxes[from];
   var across = at.x + at.wide / 2;
   var down = at.y + at.high / 2;
   var best;
   var bestLine;
   var bestAcross;
   var line;
   var side;
   var box;
   var i = 0;
   while(i < boxes.length)
   {
      box = boxes[i];
      line = box.y + box.high / 2 - down;
      side = box.x + box.wide / 2 - across;
      if(i == from)
      {
         i++;
         continue;
      }
      if(way == "up" || way == "down")
      {
         line = way == "up" ? -line : line;
         side = Math.abs(box.x - at.x);
         if(line > 2 && (best == undefined || line < bestLine - 2 || Math.abs(line - bestLine) <= 2 && side < bestAcross))
         {
            best = i;
            bestLine = line;
            bestAcross = side;
         }
      }
      else if(Math.abs(line) <= 2)
      {
         side = way == "left" ? -side : side;
         if(side > 0 && (best == undefined || side < bestAcross))
         {
            best = i;
            bestAcross = side;
         }
      }
      i++;
   }
   return best;
};

// A on a tick switches it, on a tab turns the page, on the reset puts the character back. The page is made anew, the
// focus stays on its tab
Equipment.padLookPress = function()
{
   var part = Equipment.look.lines[Equipment.padLookAt];
   if(part == undefined || part.onPress == undefined)
   {
      return undefined;
   }
   part.onPress();
   Equipment.padMark();
   Equipment.padHints();
};

// the part in focus lights as under the pointer with the gold ring around it, a value lights both its arrows
Equipment.padLookMark = function()
{
   var lines = Equipment.look.lines;
   var part;
   Equipment.padLookAt = Math.max(0, Math.min(lines.length - 1, Equipment.number(Equipment.padLookAt)));
   part = lines[Equipment.padLookAt];
   if(part == undefined)
   {
      return undefined;
   }
   Equipment.padLightLook(part, true);
   Equipment.padRingAround(part, part.wide, part.high);
   Equipment.padMarked = {look:part};
};

Equipment.padLightLook = function(part, lit)
{
   if(part.less != undefined)
   {
      part.less.lit = part.more.lit = lit;
   }
   part.lit = lit;
   part.draw(part);
};

Equipment.padLookHints = function()
{
   var menu = Equipment.menu;
   var panel = menu.navPanel;
   var part = Equipment.look.lines[Equipment.padLookAt];
   panel.clearButtons();
   if(part != undefined && part.less != undefined)
   {
      panel.addButton({text:Equipment.say("Change"), controls:Equipment.PAD_LEFT_RIGHT});
   }
   else if(part != undefined && part.page != undefined)
   {
      panel.addButton({text:Equipment.say("Open"), controls:menu._acceptControls});
   }
   else if(part != undefined)
   {
      panel.addButton({text:part.key != undefined ? Equipment.say("Switch") : Equipment.say("Reset"), controls:menu._acceptControls});
   }
   panel.addButton({text:Equipment.say("Close"), controls:menu._cancelControls});
   panel.updateButtons(true);
};

// The right stick up or down moves the long words of the card cut to fit, the plugin tells whole lines, up for the ones
// above. They stop moving by themselves for this item, as after the wheel. The browser of Know your Skyrim scrolls its
// page with the same stick while it holds the input
Equipment.padWords = function(lines)
{
   var cut = Equipment.wordsCut;
   var steps = Math.round(Number(lines));
   if(!Equipment.padReady() || Equipment.inspecting || Equipment.browserTakesStick() || cut == undefined || cut.field.maxscroll <= 1 || !cut.field._visible || Equipment.menu.itemCard._parent._visible == false || !(steps != 0))
   {
      return undefined;
   }
   cut.field.scroll = Math.max(1, Math.min(cut.field.maxscroll, cut.field.scroll - steps));
   cut.held = true;
   Equipment.drawWordsBar();
};

// What the plugin turns with the right stick: the inspected item, or the doll while the panel has the input and no
// window turns a model already. Nothing unless a gamepad plays
Equipment.PAD_TURNS_NOTHING = 0;
Equipment.PAD_TURNS_DOLL = 1;
Equipment.PAD_TURNS_ITEM = 2;
Equipment.padTurns = function()
{
   var turns = Equipment.PAD_TURNS_NOTHING;
   if(Equipment.padReady() && Equipment.inspecting)
   {
      turns = Equipment.PAD_TURNS_ITEM;
   }
   else if(Equipment.padReady() && Equipment.padFocus != undefined && !Equipment.window._visible && !(Equipment.ownCardNow() && Equipment.menu.inventoryLists.itemList.selectedIndex >= 0))
   {
      turns = Equipment.PAD_TURNS_DOLL;
   }
   if(turns != Equipment.padTurned && Equipment.plugin() != undefined)
   {
      Equipment.padTurned = turns;
      Equipment.plugin().PadTurns(turns);
   }
};

// for tests, the menu told a gamepad (1) or the keyboard (0) took over, the way the game tells it
Equipment.padPlatformAs = function(platform)
{
   Equipment.menu.SetPlatform(Number(platform), false);
};

// for tests, where the focus is and what the bottom bar says
Equipment.padReport = function(note)
{
   var at = Equipment.padFocus;
   var cell = at != undefined ? Equipment.padTarget() : undefined;
   var panel = Equipment.menu.navPanel;
   var menuLine = Equipment.padMenuUp() ? (Equipment.padLine != undefined ? Equipment.padLines()[Equipment.padLine].what.words : "up") : "closed";
   var part = Equipment.lookOpen() ? Equipment.look.lines[Equipment.padLookAt] : undefined;
   var cut = Equipment.wordsCut;
   var plugin = Equipment.plugin();
   var words = [];
   var i = 0;
   while(i < panel.buttons.length)
   {
      if(panel.buttons[i]._visible && panel.buttons[i].label.length > 0)
      {
         words.push(panel.buttons[i].label);
      }
      i++;
   }
   skse.Log("EquipmentPanel pad " + note + ": platform " + Equipment.menu._platform + ", focus " + (at == undefined ? "list" : at.kind + (cell != undefined ? " " + cell.name + (cell.parent != undefined ? "." + cell.place : "") : "") + (at.index != undefined ? " " + at.index : "")) + ", stick turns " + ["nothing", "doll", "item"][Equipment.padTurned] + ", inspect " + Equipment.inspecting + ", row menu " + menuLine +
      ", sheet " + (part == undefined ? (Equipment.lookOpen() ? "up" : "shut") : (Equipment.lookPage == "window" ? "window" : "panel") + " page at " + (part.page != undefined ? "tab " + part.page : (part.key != undefined ? part.key : "reset")) + (part.key != undefined && Equipment.settings[part.key] != undefined ? " = " + Equipment.settings[part.key] : "")) +
      ", game zoom " + (plugin != undefined && plugin.Zoomed != undefined ? plugin.Zoomed() : "-") + ", words " + (cut == undefined ? "whole" : "from line " + cut.field.scroll + " of " + cut.field.maxscroll + (cut.held ? " held" : "")) + ", bar " + words.join(" | "));
};
