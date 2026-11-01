#pragma once

// The game closes the item menus, the magic menu and a crafting station itself on the Cancel event (Escape, Tab, B),
// their scripts never get a say. With the panel in such a menu the menu asks the panel first: what the panel has up (a
// row's menu, a slot's window, the look sheet, the inspect view, the pad on the slots...) goes a step back instead.
// It began with the stations, the item menus came after, hence the name of the file
namespace Station
{
	void Install();
}
