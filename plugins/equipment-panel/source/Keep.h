#pragma once

// What the player put on a follower and took off them through the panel holds against everything else that dresses
// them: the game puts their default outfit back on as they change cells or a save loads, follower mods swap helmets
// by place or by fight, their AI picks "better" gear. Kept per follower in the save. The game's own re-dress on an
// inventory change strips them first, the player's choice goes back on right after, and its best weapon, best armor
// and outfit go nowhere a piece the player chose and the follower still carries holds. In a fight the combat AI never
// picks a weapon, shield, torch, staff or spell against it. Once the item menus are closed and someone else changed the
// follower's gear, the player's choice goes back on a moment later, in a fight too. A piece another mod changes back 3
// times, each within 10 minutes of the last time it went back, is left to that mod and the rest stay kept, the log
// tells which piece and who. [Panel] bKeepChoices off holds nothing, the choices are still noted and hold again once
// it's on. After a load what an older build left on a follower is mended once, before their first restore
namespace Keep
{
	// room in SKSE's trampoline, as many calls as that takes: five calls of the game's re-dress the gate takes and the start
	// of InitOutfitItems
	inline constexpr std::size_t kCalls = 8;

	// the game did what the player chose on a follower: a piece on (in the left hand for a weapon) or off
	void Chosen(RE::Actor& a_actor, RE::TESBoundObject& a_object, bool a_on, bool a_left);
	// Copies of the follower's outfit lost its mark in the panel and are plain items of theirs. The game's re-dress
	// adds no new set of that outfit for them, kept in the save. Whatever the switches say, the set would be free gear
	void Revealed(RE::Actor& a_actor, RE::FormID a_outfit);
	// whether the player chose gear for the actor, a lookup of the form id once any choice was made
	bool Knows(RE::FormID a_actor);
	// hears followers with choices change their gear, hooks the combat AI's score and gates the game's re-dress,
	// called once the data is loaded
	void Listen();
	// the world's frame on the main thread
	void Frame();

	constexpr std::uint32_t kRecord = 'KEEP';
	void Save(SKSE::SerializationInterface* a_save);
	void Read(SKSE::SerializationInterface* a_save, std::uint32_t a_version);
	void Forget();
}
