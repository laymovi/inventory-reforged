#pragma once

// The debug edition's answer to "does the mod cost frames": for every 10 s of the world and of each menu a line with
// the frames, their middle, the one 99 of 100 are faster than and the longest, and how much of that time was the
// plugin's own work. A frame over 50 ms is named with the plugin's share of it, and once a minute the memory the game
// holds and how much it grew. Lines "pace" in InventoryReforged.log
namespace Debug::Pace
{
	// the start of a frame of the world or of the menu named, on the main thread
	void Frame(std::string_view a_where);
}
