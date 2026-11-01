#pragma once

// Which mod put a piece of gear on a follower or took it off, for the line at the bottom of its card in their trade.
// Only a third party mod is named, never the player, the panel or the game's own dressing (its AI, its re-dress after an
// inventory change, the outfit on a load or a door). A script is caught as it calls a native that changes gear, the
// plugin of the form its script is bound to names it. The game queues a script's equip and puts it on a moment later,
// the name goes along to that equip and to whatever it pushes off. An SKSE plugin that calls the game's equip itself is
// named by its DLL. Only followers count, teammates and those Keep holds gear for, anyone else costs a flag and a lookup.
// The last change of each piece is kept in the save, 16 pieces of 64 followers, the player's change through the panel
// clears it
namespace ChangedBy
{
	struct Change
	{
		std::string by;
		bool on;
	};

	// room in SKSE's trampoline for the game's equip and unequip
	std::size_t Room();
	void Install();
	// Wraps the natives of scripts that change gear: EquipItem, UnequipItem, UnequipAll, UnequipItemSlot, SetOutfit and
	// SKSE's EquipItemEx, EquipItemById, UnequipItemEx. Once the data is loaded and again after a load, a plugin may have
	// bound one of its own in the place of one of them
	void Listen();

	std::optional<Change> Last(RE::FormID a_actor, RE::FormID a_form);
	// the player changed the piece through the panel
	void Cleared(RE::FormID a_actor, RE::FormID a_form);

	// While one lives the panel itself dresses a_actor on this thread, whatever runs around it: a script's SetOutfit, a
	// plugin's hook of the game's equip. Every equip and unequip of the panel goes inside one
	class Ours
	{
	public:
		explicit Ours(RE::FormID a_actor);
		~Ours();
		Ours(const Ours&) = delete;
		Ours& operator=(const Ours&) = delete;

	private:
		RE::FormID actor;
		const std::string* by;
		bool ours;
	};

	constexpr std::uint32_t kRecord = 'CHBY';
	void Save(SKSE::SerializationInterface* a_save);
	void Read(SKSE::SerializationInterface* a_save, std::uint32_t a_version);
	void Forget();
}
