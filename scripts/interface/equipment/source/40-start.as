// The plugin loads this file into a clip of the menu while the menu sets itself up, so the menu
// may not be there yet on the first frame
Equipment.findMenu = function()
{
   var menu = _root.Menu_mc;
   // a crafting station has its menu and lists under other names
   if(Equipment.kind == "crafting")
   {
      menu = _root.Menu;
      if(menu == undefined || menu.InventoryLists == undefined || menu.InventoryLists.itemList == undefined || menu._subtypeName == undefined)
      {
         return false;
      }
      Equipment.startCrafting(menu);
      return true;
   }
   if(menu == undefined || menu.inventoryLists == undefined || menu.inventoryLists.itemList == undefined)
   {
      return false;
   }
   Equipment.attach(menu);
   return true;
};

if(!Equipment.findMenu())
{
   this.onEnterFrame = function()
   {
      if(Equipment.findMenu())
      {
         delete this.onEnterFrame;
      }
   };
}
