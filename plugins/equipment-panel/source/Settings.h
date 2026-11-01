#pragma once

// What the player can tune. Read from Data/SKSE/Plugins/InventoryReforged.ini that ships with the mod and then
// from Data/MCM/Settings/InventoryReforged.ini where the menu keeps what was set, again each time the journal closes.
// That second file is the one MCM Helper kept, so what was set there before stays
namespace Settings
{
	enum class Pose : std::int32_t
	{
		kStanding,
		kAsInWorld
	};

	// what the corner of the item window says the item is made of, [Lines] iMadeOf, nothing, the material its keywords
	// name, or every part of the recipe that makes it
	enum class MadeOf : std::int32_t
	{
		kOff,
		kMaterial,
		kComponents
	};

	struct Values
	{
		bool panel = true;
		bool lookButton = true;
		// the panel shows the one the player trades with in a follower's trade and in Actor.OpenInventory of any mod
		bool followers = true;
		// what the player put on or took off a follower there stays so against the game and their AI
		bool keepChoices = true;
		// tabs over the doll switch the inventory and the trades of the companions near, off unless the player wants them
		bool companionTabs = false;
		// the doll in SkyUI's magic menu between the two hands and the voice
		bool magicMenu = true;
		// the character and the slots at a crafting station that makes or betters gear, pieces tried on there for show
		bool craftingMenu = true;
		// with Skyrim Souls RE and the like the camera does not turn while the inventory is open
		bool stillCamera = true;
		bool doll = true;
		Pose pose = Pose::kStanding;
		float turnSpeed = 0.5F;
		// the doll plays what mods of equipping animations play on the player as a piece goes on or off
		bool equipMotion = true;
		bool slotModels = true;
		bool rowModels = true;
		std::int32_t rowHeight = 100;
		float menuAmbient = 0.8F;
		bool wornLook = true;
		bool hideIcons = true;
		bool popup = true;
		bool doubleClickTakesOff = true;
		bool dragAndDrop = true;
		bool pieceStrips = true;
		bool arrows = true;
		bool equalSign = false;
		bool badges = false;
		bool subcategories = true;
		bool lastAdded = true;
		bool stackWeight = true;
		bool rowMenu = true;
		// a scan code of the keyboard, 0 for none
		std::int32_t stackKey = 45;
		// a dot on what came since the inventory was last closed
		bool newMarks = true;
		// junk marks, a scan code of the key that marks the row under the pointer, 36 is J
		bool junk = true;
		std::int32_t junkKey = 36;
		// in a chest or a shop the weight of a row that would slow the player is red
		bool weightWarnings = true;
		// a sign after the name of a row a quest wants
		bool questMarks = true;
		// the quests are read only for the sign of a row or the line of the window
		bool ReadsQuests() const { return questMarks || questLine; }
		// stolen copies of an item in a row of their own, read each time a list is made and each time a row moves
		bool stolenApart = true;
		// The doll in percent of the size that fits its room, and how far it stands from the middle of the room in
		// percent of the room's width to the right and of its height upward. Set in the inventory itself
		std::int32_t dollScale = 100;
		std::int32_t dollRight = 0;
		std::int32_t dollUp = 0;
		// slots the player took off the panel, bit 1 << slot in the order the panel numbers them
		std::uint32_t slotsOff = 0;
		// the panel beside the list in percent of its full width, narrowed from both sides, and how far it moves right
		// in percent of the full width, below zero left. The panel script keeps the shift within what it narrowed
		std::int32_t panelSize = 100;
		std::int32_t panelShift = 0;
		// the item window in percent of the size the panel gives it for the list and the screen
		std::int32_t windowSize = 100;
		// the words of the window in percent: the name, the card's effects and descriptions, numbers, small lines
		std::int32_t nameText = 100;
		std::int32_t wordsText = 100;
		std::int32_t numbersText = 100;
		std::int32_t quietText = 100;
		// every word of the game's own card in a chest, a shop or at home in the inventory, numbers too
		std::int32_t cardText = 100;
		// how the item window comes up over a row, [Window] iPopUp: 0 at once, 1 once the row stayed selected a moment, 2
		// the UI's own card, no window and the card and model of a row left where the UI puts them. Details of a row's menu
		// brings the window up in any of them
		std::int32_t windowShow = 0;
		bool stats = true;
		// lines of the window the player switched off one by one, bit 1 << line: the numbers in the order swing,
		// DPS, DPM, reach, stagger, crit damage, stops, whole set, effective health, armor per weight, the small lines
		// kind, how many you have, silver, stolen
		std::uint32_t numbersOff = 0;
		std::uint32_t linesOff = 0;
		MadeOf madeOf = MadeOf::kComponents;
		bool heroStats = true;
		bool slotNumbers = false;
		// quiet lines in the window: how many you have, silver, the plugin it comes from
		bool quietTags = true;
		// the quiet line From <plugin> on its own, some find the file names noise
		bool modOrigin = true;
		// the line of the window that says what a quest wants with the item, apart from the other quiet lines
		bool questLine = true;
		// a skin's own item card stays where and how the skin draws it, the window holds the model and the numbers
		bool leaveCard = false;
		bool inspectOnZoomKey = true;
		// 0xRRGGBB of what is picked or lit and of names at rest, some UI looks want other than the gold
		std::uint32_t accentColor = 0xD6B068;
		std::uint32_t textColor = 0xE6E0C8;
		// for making the standing pose table, the pose of the live player goes to a file on every menu open
		bool dumpPose = false;
		// for tests, the pages of SKSE Menu Framework open in a window of their own as the game starts
		bool pagesWindow = false;
		// for tests, off draws the doll in the game's own pass over the menu, what the pass under it costs shows
		bool dollUnder = true;
		// off gives Community Shaders' hair the world's depth in menus again, its self shadow darkened the doll's hair
		bool menuDepth = true;
		// the menus' 3D camera's near plane: -1 the game's own, 0 just before the nearest model, more a plane that far
		std::int32_t menuNear = 0;
#if IR_DEBUG_EDITION
		// for tests, the first slots of each item menu wait this many seconds, the watch has to tell it
		std::int32_t stallSeconds = 0;
		// for tests, the menu's 3D gets the near plane in Community Shaders' depth slot, hair goes dark
		bool menuDepthNear = false;
#endif
	};

	void Load();
	const Values& Get();

	// A setting of the menu by its id, "bModels:Slots" is bModels in [Slots], as both files say it together.
	// Set writes it into the menu's file, it holds once the journal closes
	float Value(std::string_view a_id);
	void Set(std::string_view a_id, float a_value);
	// The same from the panel in the inventory, there it holds at once. Only the game's own thread calls it
	void Change(std::string_view a_id, float a_value);

	// the values as an object of the menu script, names as the script reads them
	void Fill(RE::GFxMovie& a_movie, RE::GFxValue& a_object);
}
