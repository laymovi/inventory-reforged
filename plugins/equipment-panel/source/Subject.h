#pragma once

// Whom the panel shows. The player in the inventory. In a trade where the game lets the player give and take freely
// (its container menu in NPC mode: a follower's "let's trade", Actor.OpenInventory of any mod) the panel shows the one
// traded with, a person and alive: the doll, the worn slots, and what goes into a slot goes on them
namespace Subject
{
	// The panel script of a menu that loads asks whom it shows, a_container for the container menu. The menu isn't on
	// the stack of open menus yet then, so the answer is kept until an item menu closes
	RE::NiPointer<RE::Actor> Ask(bool a_container);
	void Closed();
	// the player's own update on the main thread: the follower of a trade under a running menu is held or let go here
	void WorldFrame();
	// the container menu closed: the mods that listen hear the last choices and that the trade is over
	void Finish();
	// a save loads: the choices of the trade up now are dropped untold, its menu still closes it
	void Abandon();
	// The followers held still in a trade as the game is saved. Every save of this build has the record, so one of the
	// plugin without it comes from an older build, which never let such a follower go after the trade
	constexpr std::uint32_t kMendRecord = 'MEND';
	void SaveMend(SKSE::SerializationInterface* a_save);
	void ReadMend(SKSE::SerializationInterface* a_save, std::uint32_t a_version);
	// The records of a save are read, a_ours when any was the plugin's and a_mended when the mend record was among
	// them. The next world frame lets go who the save kept held, and with an older build's save every follower out of
	// a scene still standing still
	void Loaded(bool a_ours, bool a_mended);
	// A crafting station shows the companion the player switched to by the tabs, pieces are tried on them there. No
	// trade comes of it and nothing is told to mods that listen. 0 or the player shows the player again. False when
	// the actor is no companion the panel can show
	bool ShowAtStation(RE::FormID a_actor);
	// the crafting menu closed, the player is shown again
	void LeaveStation();
	// a trade with a follower is up, an inventory over it or not
	bool Trading();
	// the player gives the follower a row to put on, their worn gear is noted first: their AI may put the gift on
	// during the move, what it pushed off is told then
	void Gift();
	// the mods that listen hear what the game did of the player's choices so far
	void Tell();

	// A mod's actor shown but not dressed: the panel looks only, slots and rows put nothing on and take nothing off.
	// Kept in the save by the actor's form id
	void SetReadOnly(RE::FormID a_actor, bool a_readOnly);
	// whether the one shown now is such an actor
	bool ReadOnly();
	bool ReadOnlyActor(RE::FormID a_actor);
	// whether the actor is the follower shown in a trade now, cheap enough for every worn item of a body built
	bool IsShown(const RE::Actor& a_actor);
#if IR_DEBUG_EDITION
	// the form id of the follower shown, 0 for none, for events of any thread
	RE::FormID ShownForm();
#endif
	std::vector<RE::FormID> ReadOnlyActors();
	void ForgetReadOnly();

	// the one the panel shows now, the player when no one else is shown
	RE::NiPointer<RE::Actor> Get();
	// someone other than the player is shown in a container menu now
	bool Other();
	// a living person who wears
	// things, beasts don't count
	bool Fits(RE::Actor& a_actor);
	// whether a trade with this actor would show the panel now, with the switches the player set
	bool Shows(RE::Actor& a_actor);

	// after the data is loaded, hears the game equip the one shown
	void Listen();
	// once a frame of a follower's trade: the body and the rows follow what the game equipped, the mods that listen
	// hear what the player chose
	void Frame();
	// the rows of the trade still point at lists the panel's own change freed, until the menu fills them anew
	bool RowsOwed();
	// an inventory opened over the trade closed and took the doll and the slot models along, the trade makes them
	// again in its next frame. Asked from the menu event, so it only marks
	void SceneAgain();
	// what the follower shows of their gear changed, a hidden slot or piece: their body is built again in the trade's
	// next frame
	void BodyAgain();
	// A body built anew while it rides, sits, lies in a ragdoll or is knocked down would come off the horse, out of the
	// chair, out of its fall. The game puts the new look on such a one in their own update later
	bool Rebuildable(RE::Actor& a_actor);

	// Puts the item of a row on the one shown or takes it off, a_index is the row's place in the game's list of the
	// menu (itemIndex of the menu script) and a_form the item the script means there. The left hand gets a weapon by
	// a_left. Only a row of their own side, the panel gives a row of the player's through the menu first. False when
	// nothing was done
	bool Wear(std::int32_t a_index, RE::FormID a_form, bool a_left, bool a_on);
	// The one shown drinks a potion or eats food of a row of their own side, the way they would by themselves. Not a
	// poison. False when nothing of it was used
	bool Use(std::int32_t a_index, RE::FormID a_form);

	// What the follower wears of their outfit. The game keeps those pieces out of the trade's rows, the slots show
	// them all the same
	struct Piece
	{
		RE::TESBoundObject* object;
		bool right;
		bool left;
	};
	std::vector<Piece> Outfit();
	// Takes a worn piece of the outfit off, it has no row to go through Wear. Keep holds it off the way it holds Wear's.
	// The copy taken off loses the outfit's mark and gets its row like any item of theirs, so does a piece of the
	// outfit Wear pushes off and one they carry unworn as their trade opens. False when they wear no such piece
	bool TakeOffPiece(RE::FormID a_form);
}
