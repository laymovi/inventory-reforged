// The game closes an item menu, the magic menu and a crafting station itself on Cancel (Escape, Tab, B on a pad), the
// menu's script never gets a say. The plugin asks panelCancel first: what the panel has up goes a step back and the
// menu stays. The keys of a Cancel stop in the outermost key handler while the panel has something to step back from,
// and so does the press that just stepped it back, so neither the panel's own keys nor SkyUI's Tab take it twice

Equipment.cancelKey = function(details)
{
   var nav = details.navEquivalent;
   return nav == gfx.ui.NavigationCode.ESCAPE || nav == gfx.ui.NavigationCode.TAB || details.skseKeycode == Equipment.PAD_B;
};

Equipment.upNow = function(clip)
{
   return clip != undefined && clip._visible == true;
};

Equipment.panelTakesCancel = function()
{
   return Equipment.inspecting == true || Equipment.upNow(Equipment.junkAsk) || Equipment.chargeListUp() == true ||
      Equipment.upNow(Equipment.context) || Equipment.upNow(Equipment.look) || Equipment.anchorSlot != undefined ||
      Equipment.pinnedRow != undefined || Equipment.pieceStrip != undefined || Equipment.padFocus != undefined;
};

// the plugin asks this when the menu is told Cancel, the topmost of what the panel has up goes, true keeps the menu
Equipment.panelCancel = function()
{
   if(!Equipment.panelTakesCancel())
   {
      return false;
   }
   Equipment.cancelStepped = true;
   if(Equipment.inspecting == true)
   {
      Equipment.leaveInspect();
   }
   else if(Equipment.upNow(Equipment.junkAsk))
   {
      Equipment.answerJunk(false);
   }
   else if(Equipment.chargeListUp() == true)
   {
      Equipment.closeChargeList();
   }
   else if(Equipment.upNow(Equipment.context))
   {
      Equipment.closeContext();
   }
   else if(Equipment.upNow(Equipment.look))
   {
      Equipment.closeLook();
   }
   else if(Equipment.anchorSlot != undefined)
   {
      Equipment.closePopup();
   }
   else if(Equipment.pinnedRow != undefined)
   {
      Equipment.unpinWindow();
   }
   else if(Equipment.pieceStrip != undefined)
   {
      Equipment.closePieces();
   }
   else
   {
      Equipment.padBack();
   }
   return true;
};

// laid over every other key handler of the menu, last of all
Equipment.holdCancel = function(menu)
{
   menu.cancelHandleInput = menu.handleInput;
   menu.handleInput = function(details, pathToFocus)
   {
      if(Equipment.cancelKey(details) && (Equipment.panelTakesCancel() || Equipment.cancelStepped == true))
      {
         if(details.value == "keyUp")
         {
            Equipment.cancelStepped = false;
         }
         return true;
      }
      return this.cancelHandleInput(details, pathToFocus);
   };
};
