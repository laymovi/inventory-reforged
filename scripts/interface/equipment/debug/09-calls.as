// The debug build puts a call of these at the start of every function of the panel and at every way out of it
// (debug_calls.py), so the plugin knows which panel functions run. This part goes first and gets no calls itself.
// Until the plugin's functions are there they do nothing, and a way out still gives back what the function returns
var EquipmentCalls = {plugin:undefined};
_global.EquipmentCalls = EquipmentCalls;

EquipmentCalls.find = function()
{
   var plugin = skse != undefined && skse.plugins != undefined ? skse.plugins.EquipmentPanel : undefined;
   if(plugin != undefined && plugin.Enter != undefined && plugin.Leave != undefined)
   {
      EquipmentCalls.plugin = plugin;
   }
   return EquipmentCalls.plugin;
};

EquipmentCalls.enter = function(id)
{
   var plugin = EquipmentCalls.plugin != undefined ? EquipmentCalls.plugin : EquipmentCalls.find();
   if(plugin != undefined)
   {
      plugin.Enter(id);
   }
};

EquipmentCalls.leave = function(id, value)
{
   if(EquipmentCalls.plugin != undefined)
   {
      EquipmentCalls.plugin.Leave(id);
   }
   return value;
};

// each part sends the names of its functions, numbered from first on
EquipmentCalls.name = function(first, names)
{
   var plugin = EquipmentCalls.plugin != undefined ? EquipmentCalls.plugin : EquipmentCalls.find();
   if(plugin != undefined && plugin.Names != undefined)
   {
      plugin.Names(names, first);
   }
};
