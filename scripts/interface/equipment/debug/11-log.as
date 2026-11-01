// The debug edition: the panel's lines go into the plugin's log beside the plugin's own, with what the menu asks of
// the game and what the player presses. Every call into the plugin is looked up first, with an older plugin the
// panel goes on as it would
Equipment.DEBUG_COUNTED_CALLS = ["UpdateItem3D", "RequestItemCardInfo", "PlaySound"];
Equipment.DEBUG_REPORT_AFTER = 300;
Equipment.DEBUG_REPORT_EVERY = 1000;

Equipment.debugPlugin = function()
{
   return skse != undefined && skse.plugins != undefined ? skse.plugins.EquipmentPanel : undefined;
};

Equipment.debugLog = function(text)
{
   var plugin = Equipment.debugPlugin();
   if(plugin != undefined && plugin.Log != undefined)
   {
      plugin.Log(String(text));
   }
};

// a line that may come many times a second, past five a second the plugin only counts it
Equipment.debugSay = function(kind, text)
{
   var plugin = Equipment.debugPlugin();
   if(plugin != undefined && plugin.Said != undefined)
   {
      plugin.Said(String(kind), String(text));
   }
};

Equipment.debugCount = function(what)
{
   var plugin = Equipment.debugPlugin();
   if(plugin != undefined && plugin.Count != undefined)
   {
      plugin.Count(String(what));
   }
};

// a value handed to the game as a few words
Equipment.debugWords = function(value)
{
   if(value == undefined)
   {
      return String(value);
   }
   if(typeof value == "string")
   {
      return "\"" + value.substr(0, 60) + "\"";
   }
   if(typeof value == "number" || typeof value == "boolean")
   {
      return String(value);
   }
   if(value instanceof Array)
   {
      return "[" + value.length + " values]";
   }
   return "an object";
};

Equipment.debugList = function(values)
{
   var told = [];
   var i = 0;
   while(values != undefined && i < values.length && i < 8)
   {
      told.push(Equipment.debugWords(values[i]));
      i++;
   }
   return told.join(", ");
};

// The lines the panel writes with skse.Log land in the log of SKSE. They go into the plugin's log too, five
// a second at most
Equipment.debugTakeSkseLog = function()
{
   if(skse == undefined || skse.Log == undefined || skse.debugLog != undefined)
   {
      return undefined;
   }
   skse.debugLog = skse.Log;
   skse.Log = function(text)
   {
      Equipment.debugSay("skse.Log", text);
      return skse.debugLog.apply(this, arguments);
   };
};

// What the menu asks of the game, the panel's calls and SkyUI's alike. The wrapper that holds models back comes around
// this one later, so what it holds back never reaches here
Equipment.debugWatchGame = function()
{
   var delegate = gfx != undefined && gfx.io != undefined ? gfx.io.GameDelegate : undefined;
   if(delegate == undefined || delegate.call == undefined || delegate.debugCall != undefined)
   {
      return undefined;
   }
   delegate.debugCall = delegate.call;
   delegate.call = function(name, args)
   {
      if(Equipment.has(Equipment.DEBUG_COUNTED_CALLS, name))
      {
         Equipment.debugCount("game call " + name);
      }
      else
      {
         Equipment.debugSay("game call " + name, "game call " + name + "(" + Equipment.debugList(args) + ")");
      }
      return delegate.debugCall.apply(this, arguments);
   };
};

// what the player presses and what lies under the pointer then
Equipment.debugMouse = {};
Equipment.debugMouse.onMouseDown = function(button)
{
   Equipment.debugSay("mouse press", "mouse press " + Equipment.number(button) + " at " + Math.round(_root._xmouse) + "," + Math.round(_root._ymouse) + " on " + String(Mouse.getTopMostEntity()));
   Equipment.debugReportSoon();
};
Equipment.debugMouse.onMouseUp = function()
{
   Equipment.debugCount("mouse release");
};
Equipment.debugMouse.onMouseMove = function()
{
   Equipment.debugCount("mouse move");
};
Equipment.debugMouse.onMouseWheel = function()
{
   Equipment.debugCount("mouse wheel");
};

// the state of the panel a moment after a press or a key, once a second at most
Equipment.debugReportSoon = function()
{
   if(Equipment.debugReportTimer != undefined || getTimer() - Equipment.number(Equipment.debugReportedAt) < Equipment.DEBUG_REPORT_EVERY)
   {
      return undefined;
   }
   Equipment.debugReportTimer = setInterval(Equipment.debugReportNow, Equipment.DEBUG_REPORT_AFTER);
};

Equipment.debugReportNow = function()
{
   clearInterval(Equipment.debugReportTimer);
   Equipment.debugReportTimer = undefined;
   Equipment.debugReportedAt = getTimer();
   if(Equipment.attached && Equipment.panelReport != undefined)
   {
      Equipment.panelReport("after a press");
   }
};

Equipment.debugStart = function()
{
   var plugin = Equipment.debugPlugin();
   Equipment.debugTakeSkseLog();
   Equipment.debugWatchGame();
   Mouse.addListener(Equipment.debugMouse);
   if(plugin != undefined && plugin.Started != undefined)
   {
      plugin.Started(Equipment.DEBUG_BUILD + ", " + Equipment.kind);
   }
};

Equipment.debugStart();
