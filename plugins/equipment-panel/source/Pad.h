#pragma once

// A gamepad in the inventory, a follower's trade and the magic menu. The click of the stick the game zooms with goes to
// the panel: a short one moves the input between the list and the panel, a hold inspects what's in focus. The right
// stick turns the doll while the panel has the input, and the inspected item while one is looked at. In a chest and a
// shop a hold opens the menu of a row and a click zooms the game's way. Up and down the stick scrolls the long words
// of a card cut to fit, in every item menu
namespace Pad
{
	void Listen();

	// what the stick turns now, the panel tells it. Only while a gamepad plays, so a drifting stick of a pad lying
	// by the keyboard turns nothing
	enum class Turns : std::int32_t
	{
		kNothing,
		kDoll,
		kItem
	};
	void SetTurns(Turns a_what);

	// once a frame of an item menu, turns what the stick holds or scrolls the words
	void Frame();

	void Closed();
}
