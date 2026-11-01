// What the debug panel tells once it's built in a menu, and the keys the menu gets. Every function of the panel
// tells the plugin when it starts and ends on its own, the debug build puts those calls in (debug_calls.py)

// frames the panel may look for its menu before the log says what it misses
Equipment.DEBUG_MISSES = 30;

// what of the menu the panel leans on is there, for the log of a skin or a UI mod the panel doesn't know
Equipment.debugMenuShape = function(menu)
{
   var lists = menu != undefined ? menu.inventoryLists : undefined;
   var list = lists != undefined ? lists.itemList : undefined;
   var parts = [["Menu_mc", menu], ["inventoryLists", lists], ["itemList", list], ["categoryList", lists != undefined ? lists.categoryList : undefined], ["itemCard", menu != undefined ? menu.itemCard : undefined], ["bottomBar", menu != undefined ? menu.bottomBar : undefined], ["_config", menu != undefined ? menu._config : undefined]];
   var told = [];
   var i = 0;
   while(i < parts.length)
   {
      told.push(parts[i][0] + (parts[i][1] != undefined ? "" : " missing"));
      i++;
   }
   if(menu != undefined)
   {
      told.push("setConfig " + typeof menu.setConfig, "handleInput " + typeof menu.handleInput, "onQuantityMenuSelect " + typeof menu.onQuantityMenuSelect, "platform " + menu._platform);
   }
   if(list != undefined && list.entryList != undefined)
   {
      told.push(list.entryList.length + " rows");
   }
   return told.join(", ");
};

// the panel looks for its menu every frame until it's there, one that never comes is told once
Equipment.debugFinding = function(original)
{
   var finding = function()
   {
      var found = original.apply(this, arguments);
      if(found != true)
      {
         Equipment.debugMisses = Equipment.number(Equipment.debugMisses) + 1;
         if(Equipment.debugMisses == Equipment.DEBUG_MISSES)
         {
            Equipment.debugLog("the panel still waits for its menu after " + Equipment.DEBUG_MISSES + " tries: " + Equipment.debugMenuShape(_root.Menu_mc));
         }
      }
      return found;
   };
   finding.debugOriginal = original;
   return finding;
};

// the line about the build comes once the panel is built
Equipment.debugJoined = function(original)
{
   var joined = function()
   {
      var result = original.apply(this, arguments);
      Equipment.debugAfterJoin();
      return result;
   };
   joined.debugOriginal = original;
   return joined;
};

// every key the menu gets and whether it took it, held keys only counted. Around the panel's handleInput
Equipment.debugWatchInput = function(menu)
{
   var original = menu != undefined ? menu.handleInput : undefined;
   if(typeof original != "function" || original.debugInput == true || (menu.__proto__ != undefined && menu.__proto__.handleInput == original))
   {
      return undefined;
   }
   menu.handleInput = function(details, pathToFocus)
   {
      var taken = original.apply(this, arguments);
      if(details != undefined && details.value == "keyHold")
      {
         Equipment.debugCount("key held");
      }
      else if(details != undefined)
      {
         Equipment.debugSay("key", "key " + details.value + " " + details.navEquivalent + " code " + details.skseKeycode + (taken == true ? ", the menu took it" : ""));
         if(details.value == "keyDown")
         {
            Equipment.debugReportSoon();
         }
      }
      return taken;
   };
   menu.handleInput.debugInput = true;
   menu.handleInput.debugOriginal = original;
};

Equipment.debugAfterJoin = function()
{
   var menu = Equipment.menu;
   Equipment.debugWatchInput(menu);
   Equipment.debugWatchGame();
   Equipment.debugLog("the panel is built in the " + Equipment.kind + " menu; " + Equipment.debugMenuShape(menu) + "; shows " + (Equipment.subject != undefined && Equipment.subject.player == false ? Equipment.subject.name : "the player"));
   if(Equipment.panelReport != undefined)
   {
      Equipment.panelReport("after the build");
   }
};

Equipment.join = Equipment.debugJoined(Equipment.join);
