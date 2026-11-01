#pragma once

// Pieces of gear tried on for show in a crafting menu, on the player or a companion the panel shows there: armor drawn
// on the body as if worn, never in the bag, never equipped. A worn piece on the same slots steps off the body meanwhile,
// what the tried piece covers (hair under a helmet, the body under a cuirass) is covered as by a worn one. A weapon tried
// on stands in the slot of the right hand and hangs on the doll in place of the worn one, the body in the world keeps
// what it holds. Each person keeps their own tried pieces while the menu is up, all of it goes as the crafting menu closes
namespace TryOn
{
	void Install();
	// false on a game whose worn pass wasn't found, nothing can be tried on there
	bool Ready();

	// puts a piece on an actor or takes it off, false for a form that isn't armor or a weapon or with no hooks. A tried piece takes the
	// slots of every other piece tried on that actor it meets, a weapon the place of another weapon
	bool Set(RE::Actor& a_actor, RE::FormID a_form, bool a_on);
	std::vector<RE::FormID> Worn(const RE::Actor& a_actor);
	// the weapon tried on an actor, none when nothing is
	RE::TESObjectWEAP* Weapon(const RE::Actor& a_actor);
	// grows with every change of what anyone has tried on, the doll is copied again on it
	std::uint32_t Changes();
	void Clear();
	// a new game or a save: nothing tried is kept, the bodies are built by the load
	void Forget();
	// the bodies whose tried pieces changed are built again, in a frame of the crafting menu
	void MenuFrame();

	// the slots the pieces tried on an actor take
	std::uint32_t Mask(const RE::Actor& a_actor);
	// whether a worn piece of the actor stays off the body for a tried one on its slots
	bool Covers(const RE::Actor& a_actor, const RE::TESBoundObject* a_object);
	// true while a tried piece goes down the game's call for worn pieces, what hides worn pieces leaves it be
	bool Injecting();
}
