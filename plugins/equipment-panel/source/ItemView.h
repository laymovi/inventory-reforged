#pragma once

// Item models in the menu: the game's own preview of the selected item, moved to where the panel
// wants it, and the models of worn items in the slots
namespace ItemView
{
	struct Slot
	{
		std::int32_t index;
		RE::FormID item;
		float centerX;
		float centerY;
		// show it as it sits on the body when it can be, its own model otherwise
		bool worn;
		// the share of the screen height the model may take
		float size;
	};

	// A list in the room's top left corner the model keeps clear of (what the item is made of), by its right edge and its
	// bottom edge from the room's middle in shares of the screen height, right and down
	struct Corner
	{
		float right;
		float down;
	};

	// places are shares of the screen, a_size is the share of the screen height the game sizes a model for, the room is
	// the free part of the window in shares of the screen height. a_growMost caps how many times the game's size the model
	// grows to fill the room, 0 for the window's own cap
	void PlacePreview(float a_centerX, float a_centerY, float a_size, float a_roomHigh, float a_roomWide, float a_growMost, std::optional<Corner> a_corner = std::nullopt);
	// for tests, what is seen of the model as it was fitted last, left, top, right and bottom as shares of the screen.
	// None while the game keeps its own place
	std::optional<std::array<float, 4>> PreviewSeen();
	// each frame of the menu: the model fills its room both ways and stands in its middle
	void FitPreview();
	void RestorePreview();
	// the same, and the models already up go back to the game's place, size and turn
	void PreviewBack();
	// where the game shows the model of an item before any of the above: shares from the left and the top, and the
	// share of the screen height it sizes it for
	std::array<float, 3> GameSpot();
	// the model of a row in the game's own place, brought in front of the doll there (the UI's own card)
	void PreviewHome();

	// gives back the slots that got a model, the rest keep their flat sign
	std::vector<std::int32_t> ShowSlots(const std::vector<Slot>& a_slots);
	// the item's own model filling a square of this share of the screen height in the middle of the screen, for its picture
	RE::NiPointer<RE::NiAVObject> PictureModel(RE::TESForm& a_item, float a_size);
	// tells the files apart an item's picture is made from, another model means another picture
	std::uint32_t PictureOf(const RE::TESForm& a_item);
	// a worn piece the game hadn't put on the body yet when its slot was shown gets another try
	void Refresh();
	void Clear();
	// a model the menu is done with keeps living a few seconds, the game may still be loading its textures
	void LetGo(RE::NiPointer<RE::NiAVObject>& a_model);
	// in the world the models that rested their seconds go, a closed menu held them until the next one
	void WorldFrame();

	// the model the item has in the world, turned the way the game turns it for a menu
	RE::NiPointer<RE::NiAVObject> Ground(RE::TESForm& a_item, RE::NiMatrix3& a_facing);
}
