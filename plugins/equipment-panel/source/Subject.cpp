#include "PCH.h"

#include "Subject.h"

#include "Api.h"
#include "ChangedBy.h"
#include "Hidden.h"
#include "Keep.h"
#include "Settings.h"
#include "WeaponGrip.h"

namespace Subject
{
	namespace
	{
		using Clock = std::chrono::steady_clock;

		constexpr RE::FormID kPersonKeyword = 0x13794;  // ActorTypeNPC
		constexpr RE::FormID kRightHand = 0x13F42;
		constexpr RE::FormID kLeftHand = 0x13F43;
		// rows filled anew at most this often, a fight under a running menu equips many times a second. A fill of a long
		// list takes longer than that, the next one waits twice as long as the last took so the menu keeps half its time
		constexpr auto kFillEvery = std::chrono::milliseconds(100);
		constexpr auto kReadyScript = "_global.Equipment.refillReady";

		// the follower of the container menu up now, 0 for none, and their form id, which an event of any thread can
		// be told by without a lock of the game
		std::atomic<RE::RefHandle> shown{ 0 };
		std::atomic<RE::FormID> shownForm{ 0 };

		// What the menu still owes the follower's look: their body built anew, the rows filled anew. Set by the game's
		// events of equipping, which may come from any thread and with a lock of the game held, so they only set these
		// and the next frame of the menu asks for the work
		std::atomic<bool> bodyOwed{ false };
		// a hidden slot or piece, the game builds nothing for it on its own
		std::atomic<bool> hiddenOwed{ false };
		std::atomic<bool> rowsOwed{ false };
		// The panel's own equip, use or take off in the trade freed the list of the copy it moved, the rows of the trade
		// still point at it until they're filled. Those fills go the next frame, past the pace that holds back the fills
		// the game's own events ask for
		std::atomic<bool> rowsOwedByPanel{ false };
		// an inventory over the trade closed, the trade makes its doll and slot models again in its next frame
		std::atomic<bool> sceneOwed{ false };
		std::atomic<Clock::rep> lastFill{ 0 };
		std::atomic<Clock::rep> fillTook{ 0 };
		std::atomic<bool> toldWait{ false };
		// how many choices the mods were told of in this trade
		std::atomic<std::int32_t> told{ 0 };
		// The follower the trade keeps where they stand, 0 for none. Under a running menu (Skyrim Souls RE) a follower
		// walks on, and Souls RE closes a trade whose one walked off past its distance: a trade from the companion tabs
		// or a mod's script, with no talk to hold them, closed under the player's hands. Souls RE lets the player walk
		// in menus too, then the follower is let go and their own follow brings them along, held again once the player
		// stood still a moment
		std::atomic<RE::RefHandle> heldStill{ 0 };
		// The hold and the letting go wait for the player's own update, the game's main thread, which runs exactly while
		// the world runs under a menu. An SKSE task ran them on another thread
		std::atomic<RE::RefHandle> holdOwed{ 0 };
		std::atomic<RE::RefHandle> releaseOwed{ 0 };
		std::atomic<bool> releaseOver{ false };
		std::atomic<Clock::rep> playerWalked{ 0 };
		std::atomic<bool> toldStill{ false };
		constexpr auto kStillFor = std::chrono::milliseconds(500);

		// 1.6.0 never let the follower go after such a trade, and a save written while one is held keeps them so. The
		// record says which ones a save kept held and that its game had the fix. A save of the plugin without the record
		// comes from an older build, its followers still standing still are let go once as it loads. Papyrus
		// SetDontMove leaves the same life state and nothing else, a mod's own hold can't be told from it, so only
		// teammates out of a scene, and only then
		constexpr std::uint32_t kMendVersion = 1;
		constexpr std::uint32_t kMostMended = 64;
		std::mutex mendLock;
		std::vector<RE::FormID> mendOwed;
		std::atomic<bool> scanOwed{ false };
		std::atomic<bool> mendAny{ false };

		// The follower held for the whole trade: one a script deletes while it's up is still there for the last events
		std::mutex heldLock;
		// kept for the whole game, a reference let go by a global as the game quits found its world gone
		auto& held = *new RE::NiPointer<RE::Actor>();

		// actors a mod wants shown but not dressed, kept in the save
		std::mutex readOnlyLock;
		std::set<RE::FormID> readOnly;
		constexpr std::size_t kMostReadOnly = 256;

		// A piece the player asked the panel to put on or take off waits for the game's word that it happened, then
		// the mods that listen hear of it. A piece the game refused never comes
		struct Choice
		{
			RE::FormID object;
			bool on;
			Clock::time_point at;
			bool left = false;
			// off because a new piece took its place, the player never took it off by hand
			bool pushed = false;
		};
		std::mutex choicesLock;
		std::vector<Choice> asked;
		std::vector<Choice> done;
		// the follower's worn gear as a gift from the player starts, their AI may put the gift on during the move
		std::set<RE::FormID> beforeGift;

		bool InventoryUp()
		{
			auto* ui = RE::UI::GetSingleton();
			return ui && ui->IsMenuOpen(RE::InventoryMenu::MENU_NAME);
		}

		bool Gear(const RE::TESForm* a_form)
		{
			return a_form && (a_form->Is(RE::FormType::Armor) || a_form->Is(RE::FormType::Weapon) || a_form->Is(RE::FormType::Ammo) || a_form->Is(RE::FormType::Light));
		}

		const RE::BGSEquipSlot* HandOf(const RE::TESBoundObject& a_object, bool a_left)
		{
			if (!a_object.Is(RE::FormType::Weapon)) {
				return nullptr;
			}
			return RE::TESForm::LookupByID<RE::BGSEquipSlot>(a_left ? kLeftHand : kRightHand);
		}

		bool WornIn(const RE::ExtraDataList& a_list, bool a_left)
		{
			return a_list.HasType(a_left ? RE::ExtraDataType::kWornLeft : RE::ExtraDataType::kWorn);
		}

		// Papyrus Actor.SetDontMove does these two (54761 on 1.7.104, 53937 on 1.5.97, the same code): the life state
		// of one who stays where they stand, then what stops their steps now
		constexpr std::uint32_t kAlive = 0;
		constexpr std::uint32_t kStandsStill = 9;
		constexpr REL::RelocationID kDontMove{ 36490, 37489 };
		constexpr REL::RelocationID kStopMoving{ 36802, 37818 };
		// the fill of both sides of a trade, the container menu's own
		constexpr REL::RelocationID kFillTrade{ 50215, 51144 };

		void DontMove(RE::Actor& a_actor, bool a_still)
		{
			static const REL::Relocation<void(RE::Actor*, bool)> dontMove{ kDontMove };
			static const REL::Relocation<void(RE::Actor*)> stop{ kStopMoving };
			dontMove(&a_actor, a_still);
			if (a_still) {
				stop(&a_actor);
			}
		}

		std::uint32_t LifeState(const RE::Actor& a_actor)
		{
			const auto* state = a_actor.AsActorState();
			return state ? static_cast<std::uint32_t>(state->GetLifeState()) : kAlive;
		}

		bool InScene(RE::Actor& a_actor)
		{
			return a_actor.GetActorRuntimeData().currentProcess && a_actor.GetCurrentScene();
		}

		void Mend()
		{
			std::vector<RE::FormID> ids;
			{
				const std::scoped_lock lock{ mendLock };
				ids.swap(mendOwed);
			}
			std::vector<RE::Actor*> stuck;
			for (const auto id : ids) {
				if (auto* actor = RE::TESForm::LookupByID<RE::Actor>(id); actor && LifeState(*actor) == kStandsStill) {
					stuck.push_back(actor);
				}
			}
			if (scanOwed.exchange(false)) {
				const auto started = Clock::now();
				std::size_t teammates = 0;
				const auto [forms, formsLock] = RE::TESForm::GetAllForms();
				if (forms) {
					const RE::BSReadLockGuard guard{ formsLock.get() };
					for (const auto& [id, form] : *forms) {
						auto* actor = form && form->Is(RE::FormType::ActorCharacter) ? form->As<RE::Actor>() : nullptr;
						if (!actor || actor->IsPlayerRef() || !actor->IsPlayerTeammate()) {
							continue;
						}
						++teammates;
						if (LifeState(*actor) == kStandsStill && !InScene(*actor) && std::ranges::find(stuck, actor) == stuck.end()) {
							stuck.push_back(actor);
						}
					}
				}
				logger::info("a save of an older build of the mod, its {} followers looked through in {} ms for one a trade left standing still",
					teammates, std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now() - started).count());
			}
			for (auto* actor : stuck) {
				DontMove(*actor, false);
				logger::info("{} {:08X} walks again, a trade left them standing still in the save", actor->GetName(), actor->GetFormID());
			}
		}

		// The game's own trade comes from a talk, which holds the follower. Under a running menu one the trade opened
		// otherwise stands still the same way while it's up. One a mod holds already stays that mod's, before and after
		void HoldStill()
		{
			const auto handle = shown.load();
			if (handle != 0 && heldStill.load() != handle) {
				holdOwed = handle;
			}
		}

		void LetGo(bool a_over)
		{
			holdOwed = 0;
			if (const auto handle = heldStill.exchange(0); handle != 0) {
				releaseOwed = handle;
				releaseOver = a_over;
			}
		}

		bool Worn(const RE::ExtraDataList& a_list)
		{
			return a_list.HasType(RE::ExtraDataType::kWorn) || a_list.HasType(RE::ExtraDataType::kWornLeft);
		}

		RE::InventoryEntryData* LiveEntry(RE::Actor& a_actor, const RE::TESBoundObject& a_object)
		{
			auto* changes = a_actor.GetInventoryChanges();
			if (!changes || !changes->entryList) {
				return nullptr;
			}
			for (auto* entry : *changes->entryList) {
				if (entry && entry->object == &a_object) {
					return entry;
				}
			}
			return nullptr;
		}

		std::set<RE::FormID> WornGear(RE::Actor& a_actor)
		{
			std::set<RE::FormID> worn;
			auto* changes = a_actor.GetInventoryChanges();
			if (!changes || !changes->entryList) {
				return worn;
			}
			for (auto* entry : *changes->entryList) {
				if (!entry || !entry->object || !entry->extraLists || !entry->object->GetPlayable() || !Gear(entry->object)) {
					continue;
				}
				for (const auto* list : *entry->extraLists) {
					if (list && Worn(*list)) {
						worn.insert(entry->object->GetFormID());
					}
				}
			}
			return worn;
		}

		// The copies of the default outfit the follower carries and doesn't wear lose its mark and are plain items of
		// theirs. The trade drops each copy marked with the default outfit from its row and the row's count (51171, 50239
		// on 1.5.97), so a piece taken off or pushed off by another was nowhere. A worn one keeps the mark, the slots show
		// it. Copies of another outfit have their rows already. The game would add a new set once none is marked, Keep
		// stops that
		bool Reveal(RE::Actor& a_actor)
		{
			const auto* base = a_actor.GetActorBase();
			const auto* outfit = base ? base->defaultOutfit : nullptr;
			auto* changes = a_actor.GetInventoryChanges();
			if (!outfit || !changes || !changes->entryList) {
				return false;
			}
			bool any = false;
			for (auto* entry : *changes->entryList) {
				if (!entry || !entry->object || !entry->extraLists || !entry->object->GetPlayable()) {
					continue;
				}
				for (auto* list : *entry->extraLists) {
					const auto* mark = list ? list->GetByType<RE::ExtraOutfitItem>() : nullptr;
					if (!mark || mark->id != outfit->GetFormID() || Worn(*list)) {
						continue;
					}
					// The copy keeps its count, the list's ExtraCount or 1 without it (11704), and the item's count is the
					// container's and countDelta, which the mark never touched. A list left with nothing stays: it counts
					// as one plain copy all the same, and freeing it is the game's own work, a list freed under a row of
					// the trade crashed StolenRows
					list->RemoveByType(RE::ExtraDataType::kOutfitItem);
					any = true;
					logger::info("{} of the outfit of {} is an item of theirs now, the trade lists it", entry->object->GetName(), a_actor.GetName());
				}
			}
			if (any) {
				Keep::Revealed(a_actor, outfit->GetFormID());
			}
			return any;
		}

		struct Held
		{
			RE::TESBoundObject* object;
			RE::ExtraDataList* list;
			bool left;
		};

		// What the new piece takes the place of: armor on any of its body slots, what's in its hand, and the other
		// hand too for a weapon of both hands, another copy of the same item too. A piece a script keeps on with the
		// force flag is never pushed off by the game's equip, it comes off by hand first. a_going is the copy that goes on
		std::vector<Held> InTheWay(RE::Actor& a_actor, RE::TESBoundObject& a_object, const RE::ExtraDataList* a_going, bool a_left)
		{
			std::vector<Held> found;
			auto* changes = a_actor.GetInventoryChanges();
			if (!changes || !changes->entryList) {
				return found;
			}
			const auto* armor = a_object.As<RE::TESObjectARMO>();
			const bool weapon = a_object.Is(RE::FormType::Weapon);
			const bool both = WeaponGrip::BothHands(&a_object);
			const bool shield = armor && armor->IsShield();
			const bool light = a_object.Is(RE::FormType::Light);
			const bool leftHand = shield || light || (weapon && a_left);
			for (auto* entry : *changes->entryList) {
				// What can't be played with is a mod's own piece, a body of Devious Devices or the like: it has no row
				// to put it back by and its mod keeps it on, the game's own equip decides about it
				if (!entry || !entry->object || !entry->extraLists || !entry->object->GetPlayable()) {
					continue;
				}
				const auto* other = entry->object->As<RE::TESObjectARMO>();
				const bool otherWeapon = entry->object->Is(RE::FormType::Weapon);
				const bool otherBoth = WeaponGrip::BothHands(entry->object);
				for (auto* list : *entry->extraLists) {
					if (!list || list == a_going) {
						continue;
					}
					const bool right = list->HasType(RE::ExtraDataType::kWorn);
					const bool left = list->HasType(RE::ExtraDataType::kWornLeft);
					bool clashes = false;
					if (armor && !shield) {
						clashes = other && right && (other->GetSlotMask().underlying() & armor->GetSlotMask().underlying()) != 0;
					} else if (a_object.Is(RE::FormType::Ammo)) {
						clashes = right && entry->object->Is(RE::FormType::Ammo);
					} else if (weapon || shield || light) {
						// a weapon and a torch in the left hand carry its mark, a shield there the plain worn mark. A weapon
						// of both hands holds both with either mark
						const bool holdsLeft = left || (right && ((other && other->IsShield()) || entry->object->Is(RE::FormType::Light)));
						const bool holdsRight = right && otherWeapon;
						clashes = (leftHand && holdsLeft) || (!leftHand && holdsRight) || ((both || otherBoth) && (holdsLeft || holdsRight));
					}
					if (clashes) {
						found.push_back({ entry->object, list, left });
					}
				}
			}
			return found;
		}

		class EquipWatch : public RE::BSTEventSink<RE::TESEquipEvent>
		{
		public:
			RE::BSEventNotifyControl ProcessEvent(const RE::TESEquipEvent* a_event, RE::BSTEventSource<RE::TESEquipEvent>*) override
			{
				const auto form = shownForm.load();
				if (!a_event || form == 0 || !a_event->actor || a_event->actor->GetFormID() != form || !Gear(RE::TESForm::LookupByID(a_event->baseObject))) {
					return RE::BSEventNotifyControl::kContinue;
				}
				bodyOwed = true;
				rowsOwed = true;
				const std::scoped_lock lock{ choicesLock };
				const auto chosen = std::ranges::find_if(asked, [&](const Choice& a_choice) { return a_choice.object == a_event->baseObject && a_choice.on == a_event->equipped; });
				if (chosen != asked.end()) {
					done.push_back(*chosen);
					asked.erase(chosen);
				}
				return RE::BSEventNotifyControl::kContinue;
			}
		};

		// The rows are filled anew only while the menu script says nothing holds a row: no slider asking how many, no
		// drag, no menu of a row. The game's moves act on the selected row by its place, a fill under them would
		// hand them another row
		bool MenuReady(RE::IMenu& a_menu)
		{
			RE::GFxValue ready;
			IR_SCRIPT_QUIET(kReadyScript);
			return a_menu.uiMovie && a_menu.uiMovie->Invoke(kReadyScript, &ready, nullptr, 0) && ready.IsBool() && ready.GetBool();
		}
	}

	// An item menu loads. The inventory or a shop leave a trade under them as it is: a script's inventory over a
	// trade the game may never open, and the trade went on with the player's doll beside the follower's slots when
	// this ended it. A new container menu ends a trade still up first, with its events told
	RE::NiPointer<RE::Actor> Ask(bool a_container)
	{
		if (!a_container) {
			return Get();
		}
		Finish();
		if (!Settings::Get().followers || RE::ContainerMenu::GetContainerMode() != RE::ContainerMenu::ContainerMode::kNPCMode) {
			return Get();
		}
		const auto handle = RE::ContainerMenu::GetTargetRefHandle();
		const auto target = RE::TESObjectREFR::LookupByHandle(handle);
		auto* actor = target ? target->As<RE::Actor>() : nullptr;
		if (actor && !actor->IsPlayerRef() && Fits(*actor)) {
			{
				const std::scoped_lock lock{ heldLock };
				held.reset(actor);
			}
			shownForm = actor->GetFormID();
			shown = handle;
			logger::info("the panel shows {} in their trade", actor->GetName());
			// the menu fills its rows after this, the fill the panel asks for once it's ready covers a menu that filled
			// them already
			if (!ReadOnlyActor(actor->GetFormID()) && Reveal(*actor)) {
				rowsOwed = true;
			}
		}
		return Get();
	}

	// the player's own update, on the game's main thread
	void WorldFrame()
	{
		if (mendAny.exchange(false)) {
			Mend();
		}
		if (const auto handle = releaseOwed.exchange(0); handle != 0) {
			const auto target = RE::TESObjectREFR::LookupByHandle(handle);
			auto* actor = target ? target->As<RE::Actor>() : nullptr;
			if (actor && LifeState(*actor) == kStandsStill) {
				DontMove(*actor, false);
				if (releaseOver.load()) {
					logger::info("{} walks again, their trade is over", actor->GetName());
				}
			}
		}
		const auto handle = holdOwed.exchange(0);
		if (handle == 0 || shown.load() != handle || heldStill.load() == handle) {
			return;
		}
		const auto target = RE::TESObjectREFR::LookupByHandle(handle);
		auto* actor = target ? target->As<RE::Actor>() : nullptr;
		if (!actor || LifeState(*actor) != kAlive) {
			return;
		}
		DontMove(*actor, true);
		heldStill = handle;
		if (!toldStill.exchange(true)) {
			logger::info("{} stands still while their trade is up and the player does, the game runs under the menu", actor->GetName());
		}
	}

	namespace
	{
		// what the trade told and was asked goes with it, the follower's hold stays for the next world frame to let go
		void ForgetTrade()
		{
			told = 0;
			sceneOwed = false;
			{
				const std::scoped_lock lock{ choicesLock };
				asked.clear();
				done.clear();
				beforeGift.clear();
			}
			const std::scoped_lock lock{ heldLock };
			held.reset();
		}
	}

	void Closed()
	{
		LetGo(true);
		toldStill = false;
		shown = 0;
		shownForm = 0;
		bodyOwed = false;
		hiddenOwed = false;
		rowsOwed = false;
		rowsOwedByPanel = false;
		toldWait = false;
		// Abandon here wiped the release LetGo just asked for, every follower held under a running menu kept standing
		// after the trade and ran on the spot behind the player (seen with SkySouls)
		ForgetTrade();
	}

	// A save loads while a trade is up: its last choices go nowhere, the new game's listeners never heard of them.
	// The trade itself is closed by its menu as the game closes every menu, that takes the doll and models away
	void Abandon()
	{
		// the one held belongs to the game that's gone
		heldStill = 0;
		holdOwed = 0;
		releaseOwed = 0;
		scanOwed = false;
		mendAny = false;
		{
			const std::scoped_lock lock{ mendLock };
			mendOwed.clear();
		}
		ForgetTrade();
	}

	void SaveMend(SKSE::SerializationInterface* a_save)
	{
		std::vector<RE::FormID> kept;
		for (const auto handle : { heldStill.load(), releaseOwed.load() }) {
			const auto target = handle != 0 ? RE::TESObjectREFR::LookupByHandle(handle) : nullptr;
			if (target) {
				kept.push_back(target->GetFormID());
			}
		}
		{
			const std::scoped_lock lock{ mendLock };
			kept.insert(kept.end(), mendOwed.begin(), mendOwed.end());
		}
		if (!a_save->OpenRecord(kMendRecord, kMendVersion)) {
			logger::error("the followers held in a trade could not be saved");
			return;
		}
		a_save->WriteRecordData(static_cast<std::uint32_t>(kept.size()));
		for (const auto id : kept) {
			a_save->WriteRecordData(id);
		}
	}

	void ReadMend(SKSE::SerializationInterface* a_save, std::uint32_t a_version)
	{
		std::uint32_t count = 0;
		if (a_version != kMendVersion || !a_save->ReadRecordData(count)) {
			return;
		}
		std::vector<RE::FormID> read;
		for (std::uint32_t at = 0; at < count && at < kMostMended; ++at) {
			RE::FormID saved = 0;
			RE::FormID now = 0;
			if (!a_save->ReadRecordData(saved)) {
				break;
			}
			if (a_save->ResolveFormID(saved, now)) {
				read.push_back(now);
			}
		}
		if (!read.empty()) {
			const std::scoped_lock lock{ mendLock };
			mendOwed = std::move(read);
			mendAny = true;
		}
	}

	void Loaded(bool a_ours, bool a_mended)
	{
		if (a_ours && !a_mended) {
			scanOwed = true;
			mendAny = true;
		}
	}

	bool ShowAtStation(RE::FormID a_actor)
	{
		auto* actor = a_actor != 0 ? RE::TESForm::LookupByID<RE::Actor>(a_actor) : nullptr;
		if (!actor || actor->IsPlayerRef()) {
			LeaveStation();
			return true;
		}
		if (!actor->IsPlayerTeammate() || !Shows(*actor)) {
			return false;
		}
		{
			const std::scoped_lock lock{ heldLock };
			held.reset(actor);
		}
		shownForm = actor->GetFormID();
		shown = actor->GetHandle().native_handle();
		logger::info("the panel shows {} at the crafting station", actor->GetName());
		return true;
	}

	void LeaveStation()
	{
		if (shown.load() == 0) {
			return;
		}
		Closed();
	}

	void Gift()
	{
		const auto actor = Other() ? Get() : nullptr;
		auto worn = actor ? WornGear(*actor) : std::set<RE::FormID>{};
		const std::scoped_lock lock{ choicesLock };
		beforeGift = std::move(worn);
	}

	// The trade closes: what the game did of the last choices is told first, then that the trade is over, so a mod
	// that keeps a set of gear saves it whole once. Told of the actor held since the trade opened
	void Finish()
	{
		RE::NiPointer<RE::Actor> actor;
		{
			const std::scoped_lock lock{ heldLock };
			actor = held;
		}
		if (actor && shown.load() != 0) {
			Tell();
			Api::Done(*actor, told.load() > 0);
		}
		Closed();
	}

	void SetReadOnly(RE::FormID a_actor, bool a_readOnly)
	{
		const std::scoped_lock lock{ readOnlyLock };
		if (!a_readOnly) {
			readOnly.erase(a_actor);
		} else if (readOnly.size() < kMostReadOnly) {
			readOnly.insert(a_actor);
		} else {
			static bool told = false;
			if (!std::exchange(told, true)) {
				logger::warn("SetReadOnly: {} actors are looked at only already, {:08X} and any after it are not taken", kMostReadOnly, a_actor);
			}
		}
	}

	bool ReadOnly()
	{
		return ReadOnlyActor(shownForm.load());
	}

	bool ReadOnlyActor(RE::FormID a_actor)
	{
		const std::scoped_lock lock{ readOnlyLock };
		return a_actor != 0 && readOnly.contains(a_actor);
	}

	bool IsShown(const RE::Actor& a_actor)
	{
		return shownForm.load() == a_actor.GetFormID();
	}

#if IR_DEBUG_EDITION
	RE::FormID ShownForm()
	{
		return shownForm.load();
	}
#endif

	// What goes into the save. An actor made in the game and deleted since stays out, a new one made later may get its
	// form id. One of a plugin stays whether found or not, its cell may only be unloaded now
	std::vector<RE::FormID> ReadOnlyActors()
	{
		const std::scoped_lock lock{ readOnlyLock };
		std::erase_if(readOnly, [](RE::FormID a_form) {
			if ((a_form >> 24) != 0xFF) {
				return false;
			}
			const auto* actor = RE::TESForm::LookupByID<RE::Actor>(a_form);
			return !actor || actor->IsDeleted();
		});
		return { readOnly.begin(), readOnly.end() };
	}

	void ForgetReadOnly()
	{
		const std::scoped_lock lock{ readOnlyLock };
		readOnly.clear();
	}

	// A follower gone from the game while their trade is up (a script deleted them) leaves no one, never the player.
	// An inventory up over the trade is the player's
	RE::NiPointer<RE::Actor> Get()
	{
		if (const auto handle = shown.load(); handle != 0 && !InventoryUp()) {
			const auto target = RE::TESObjectREFR::LookupByHandle(handle);
			auto* actor = target ? target->As<RE::Actor>() : nullptr;
			return RE::NiPointer<RE::Actor>(actor && !actor->IsDeleted() ? actor : nullptr);
		}
		return RE::NiPointer<RE::Actor>(RE::PlayerCharacter::GetSingleton());
	}

	bool Other()
	{
		return shown.load() != 0 && !InventoryUp();
	}

	bool Trading()
	{
		return shown.load() != 0;
	}

	// A person, alive, there in the world with a body. One far away or disabled has no process the game equips
	// through, and parts of the character sheet are asked of loaded actors only
	bool Fits(RE::Actor& a_actor)
	{
		static const auto* person = RE::TESForm::LookupByID<RE::BGSKeyword>(kPersonKeyword);
		const auto* race = a_actor.GetRace();
		// with its AI off it's a mannequin or a statue a mod posed, its own script dresses it and a body built anew
		// would lose the pose
		return person && race && race->HasKeyword(person) && !a_actor.IsDead() && !a_actor.IsDisabled() && a_actor.Is3DLoaded() && a_actor.IsAIEnabled();
	}

	bool Shows(RE::Actor& a_actor)
	{
		const auto& settings = Settings::Get();
		return settings.panel && settings.followers && !a_actor.IsPlayerRef() && Fits(a_actor);
	}

	void Listen()
	{
		static EquipWatch equips;
		RE::ScriptEventSourceHolder::GetSingleton()->AddEventSink<RE::TESEquipEvent>(&equips);
	}

	// the mods that listen hear what the game did of the player's choices
	void Tell()
	{
		std::vector<Choice> heard;
		{
			const std::scoped_lock lock{ choicesLock };
			heard.swap(done);
		}
		RE::NiPointer<RE::Actor> actor;
		{
			const std::scoped_lock lock{ heldLock };
			actor = held;
		}
		for (const auto& choice : heard) {
			if (auto* object = RE::TESForm::LookupByID(choice.object); actor && object) {
				Api::Worn(*actor, *object, choice.on);
				// the line of which mod changed it goes, the player changed it last
				ChangedBy::Cleared(actor->GetFormID(), choice.object);
				// what a new piece pushed off isn't held off, the new one kept on pushes it again if it comes back
				if (auto* bound = object->As<RE::TESBoundObject>(); bound && !choice.pushed) {
					Keep::Chosen(*actor, *bound, choice.on, choice.left);
				}
				++told;
			}
		}
	}

	void SceneAgain()
	{
		sceneOwed = true;
	}

	void BodyAgain()
	{
		hiddenOwed = true;
	}

	bool Rebuildable(RE::Actor& a_actor)
	{
		const auto* state = a_actor.AsActorState();
		return a_actor.Is3DLoaded() && !a_actor.IsOnMount() && !a_actor.IsInRagdollState() && !a_actor.IsInKillMove() &&
		       (!state || (state->GetSitSleepState() == RE::SIT_SLEEP_STATE::kNormal && state->GetKnockState() == RE::KNOCK_STATE_ENUM::kNormal && !state->IsBleedingOut()));
	}

	// Once a frame of the trade. The mods that listen hear what the game did of the player's choices. The body is
	// built anew and the rows filled anew as a task of the interface once the scripts of this frame are done. The
	// fill is the container menu's own, the one it runs when its view changes, both sides from the inventories. After
	// an equip the body only under a paused menu: the game puts a follower's new look on them in their own update,
	// which waits then, and under a running menu a body built anew mid swing would only cost. A hide is built always,
	// under a running menu (Skyrim Souls RE) nothing else builds it until the menu closes
	void Frame()
	{
		const auto handle = shown.load();
		if (handle == 0) {
			return;
		}
		if (sceneOwed.exchange(false)) {
			SKSE::GetTaskInterface()->AddUITask([] {
				if (const auto menu = RE::UI::GetSingleton()->GetMenu(RE::ContainerMenu::MENU_NAME); menu && menu->uiMovie) {
					IR_SCRIPT("_global.Equipment.sceneAgain");
					menu->uiMovie->Invoke("_global.Equipment.sceneAgain", nullptr, nullptr, 0);
				}
			});
		}
		const auto now = Clock::now();
		Tell();
		const bool paused = RE::UI::GetSingleton()->GameIsPaused();
		if (!paused) {
			const auto* player = RE::PlayerCharacter::GetSingleton();
			if (player && player->IsMoving()) {
				playerWalked = now.time_since_epoch().count();
				LetGo(false);
			} else if (now - Clock::time_point(Clock::duration(playerWalked.load())) >= kStillFor) {
				HoldStill();
			}
		}
		// a single |, both are taken this frame
		const bool body = (bodyOwed.exchange(false) && paused) | hiddenOwed.exchange(false);
		const auto pause = std::max<Clock::duration>(kFillEvery, Clock::duration(fillTook.load()) * 2);
		const bool soon = now - Clock::time_point(Clock::duration(lastFill.load())) < pause && !rowsOwedByPanel.load();
		const bool rows = !soon && rowsOwed.exchange(false);
		if (rows) {
			rowsOwedByPanel = false;
		}
		if (!body && !rows) {
			return;
		}
		if (rows) {
			lastFill = now.time_since_epoch().count();
		}
		SKSE::GetTaskInterface()->AddUITask([handle, body, rows] {
			if (shown.load() != handle) {
				return;
			}
			const auto target = RE::TESObjectREFR::LookupByHandle(handle);
			auto* actor = target ? target->As<RE::Actor>() : nullptr;
			if (actor && body && Rebuildable(*actor)) {
				IR_BRACKET("the body of {:08X} is built again for the trade", actor->GetFormID());
				if (auto* process = actor->GetActorRuntimeData().currentProcess) {
					process->Set3DUpdateFlag(RE::RESET_3D_FLAGS::kModel);
				}
				actor->Update3DModel();
				Hidden::BodyBuilt(*actor);
			}
			const auto menu = RE::UI::GetSingleton()->GetMenu<RE::ContainerMenu>();
			if (menu && rows) {
				if (!MenuReady(*menu)) {
					rowsOwed = true;
					if (!toldWait.exchange(true)) {
						logger::info("the rows of the trade wait for a fill, the menu holds a row");
					}
					return;
				}
				static const REL::Relocation<void(RE::ContainerMenu*)> fill{ kFillTrade };
				IR_BRACKET("the trade fills its rows anew");
				const auto start = Clock::now();
				fill(menu.get());
				fillTook = (Clock::now() - start).count();
			}
		});
	}

	namespace
	{
		struct ShownRow
		{
			RE::NiPointer<RE::Actor> actor;
			RE::ItemList* list = nullptr;
			RE::ItemList::Item* item = nullptr;
			RE::InventoryEntryData* row = nullptr;
			RE::TESBoundObject* object = nullptr;
		};

		std::int32_t CountOf(RE::Actor& a_actor, RE::TESBoundObject& a_object)
		{
			const auto items = a_actor.GetInventory([&](RE::TESBoundObject& a_item) { return &a_item == &a_object; });
			const auto found = items.find(&a_object);
			return found != items.end() ? found->second.first : 0;
		}

		// The row of the trade a script asks about, when the follower shown can be dressed and the row still holds the
		// item the script means and is theirs. The menu's row is a copy made when it last filled its rows, a script or
		// the follower's AI may have changed their things since. It only names the item and which of its copies, the
		// lists themselves are taken from the follower's inventory as it is now. A row that moved meanwhile is refused
		std::optional<ShownRow> RowOfShown(std::string_view a_call, std::int32_t a_index, RE::FormID a_form)
		{
			ShownRow found;
			found.actor = Get();
			const auto& actor = found.actor;
			if (!actor || actor.get() == RE::PlayerCharacter::GetSingleton() || !actor->Is3DLoaded() || ReadOnly()) {
				IR_LOG("{} refused: {}", a_call, !actor ? "no one is shown" : (actor.get() == RE::PlayerCharacter::GetSingleton() ? "the player is shown" :
					(!actor->Is3DLoaded() ? "the one shown has no body loaded" : "a mod keeps the one shown read only")));
				return std::nullopt;
			}
			const auto menu = RE::UI::GetSingleton()->GetMenu<RE::ContainerMenu>();
			found.list = menu ? menu->GetRuntimeData().itemList : nullptr;
			if (!found.list || a_index < 0 || static_cast<std::uint32_t>(a_index) >= found.list->items.size()) {
				IR_LOG("{} refused: {}", a_call, !found.list ? "no list of a trade" : fmt::format("no row {} among {}", a_index, found.list->items.size()));
				return std::nullopt;
			}
			found.item = found.list->items[static_cast<std::uint32_t>(a_index)];
			found.row = found.item ? found.item->data.objDesc : nullptr;
			found.object = found.row ? found.row->object : nullptr;
			if (!found.object || found.object->GetFormID() != a_form || RE::TESObjectREFR::LookupByHandle(found.item->data.owner).get() != actor.get()) {
				IR_LOG("{} refused: row {} holds {:08X}, the panel asked for {:08X}, or the row isn't of the one shown", a_call, a_index,
					found.object ? found.object->GetFormID() : 0, a_form);
				return std::nullopt;
			}
			return found;
		}
	}

	bool Wear(std::int32_t a_index, RE::FormID a_form, bool a_left, bool a_on)
	{
		const auto shown = RowOfShown("Wear", a_index, a_form);
		if (!shown) {
			return false;
		}
		const auto& actor = shown->actor;
		auto* list = shown->list;
		auto* item = shown->item;
		auto* row = shown->row;
		auto* object = shown->object;
		// The hand counts for a weapon alone. A shield is worn with the plain mark, a torch with the mark of the left
		// hand, either of their worn copies is the one
		const bool weapon = object->Is(RE::FormType::Weapon);
		const bool left = a_left && weapon;
		// The copies of this row by their lists. A row of plain copies names none, it owns every copy the other rows of
		// the same item don't: a superior helmet is a row of its own beside the plain ones
		std::vector<const RE::ExtraDataList*> named;
		std::vector<const RE::ExtraDataList*> others;
		for (const auto* other : list->items) {
			auto* copy = other ? other->data.objDesc : nullptr;
			if (!copy || copy->object != object || !copy->extraLists) {
				continue;
			}
			for (const auto* copyList : *copy->extraLists) {
				(copy == row ? named : others).push_back(copyList);
			}
		}
		const auto ofRow = [&](const RE::ExtraDataList* a_list) {
			return named.empty() ? std::ranges::find(others, a_list) == others.end() : std::ranges::find(named, a_list) != named.end();
		};
		auto* live = LiveEntry(*actor, *object);
		RE::ExtraDataList* going = nullptr;
		RE::ExtraDataList* coming = nullptr;
		bool already = false;
		bool otherHand = false;
		if (live && live->extraLists) {
			for (auto* copy : *live->extraLists) {
				// a copy of the outfit is no row's, a plain armor put on goes in its place
				if (!copy || copy->HasType(RE::ExtraDataType::kOutfitItem) || !ofRow(copy)) {
					continue;
				}
				if (weapon ? WornIn(*copy, left) : Worn(*copy)) {
					coming = coming ? coming : copy;
					already = true;
				} else if (Worn(*copy)) {
					otherHand = true;
				} else if (!going) {
					going = copy;
				}
			}
		}
		// with no copy of the row's own left unworn the game picks a plain one, a second sword for the other hand
		if (!a_on && !coming) {
			IR_LOG("Wear refused: {:08X} {} has no worn copy of the row to take off", object->GetFormID(), object->GetName());
			return false;
		}
		// The whole stack of arrows goes on, the way the game puts them on the player. The row's count is the stack, the
		// inventory keeps only how many more or fewer there are than the actor's record gives
		const auto count = object->Is(RE::FormType::Ammo) ? std::max<std::uint32_t>(item->data.GetCount(), 1) : 1;
		const auto inTheWay = a_on ? InTheWay(*actor, *object, already ? coming : going, left) : std::vector<Held>{};
		// the only copy of a weapon, worn in the other hand, moves: it comes off there first
		const bool moves = a_on && !already && !going && otherHand;
		const auto now = Clock::now();
		const auto wornNow = a_on && already ? WornGear(*actor) : std::set<RE::FormID>{};
		{
			const std::scoped_lock lock{ choicesLock };
			// A piece the follower put on by themselves when it was given is the player's choice all the same, the game
			// sends no word of an equip that changes nothing. What it pushed off then came off by the gift, it's told
			// first, as the worn gear before the gift and now tell it
			if (a_on && already) {
				for (const auto form : beforeGift) {
					if (!wornNow.contains(form)) {
						done.push_back({ form, false, now, false, true });
					}
				}
				done.push_back({ object->GetFormID(), true, now, left });
			} else {
				if (moves) {
					asked.push_back({ object->GetFormID(), false, now, !left });
				}
				asked.push_back({ object->GetFormID(), a_on, now, left });
			}
			for (const auto& held : inTheWay) {
				asked.push_back({ held.object->GetFormID(), false, now, held.left, true });
			}
			beforeGift.clear();
		}
		// A follower picks their gear anew whenever their inventory changes. What goes on through the panel is held by
		// Keep while [Panel] bKeepChoices is on: its gate on the game's re-dress at every inventory change puts nothing
		// in its place, the combat AI's score never picks against it, and what changed anyway goes back once the menus
		// close. No force flag, the game saves it on the copy and it outlives the mod. What stands in the way of a new
		// piece comes off first, a piece a script keeps on with that flag would stay where the new one goes
		auto* equip = RE::ActorEquipManager::GetSingleton();
		// the player's choice, whatever plugin hooks the game's equip in between
		const ChangedBy::Ours ours{ actor->GetFormID() };
		if (a_on) {
			for (const auto& held : inTheWay) {
				const auto stack = static_cast<std::uint32_t>(held.object->Is(RE::FormType::Ammo) ? std::max<std::int32_t>(held.list->GetCount(), 1) : 1);
				IR_BRACKET("unequip {:08X} {} from {:08X} in the way, list {}, {} of it", held.object->GetFormID(), held.object->GetName(), actor->GetFormID(),
					static_cast<const void*>(held.list), stack);
				equip->UnequipObject(actor.get(), held.object, held.list, stack, HandOf(*held.object, held.left), false, true, false, true);
			}
			IR_BRACKET("equip {:08X} {} on {:08X}, list {}, {} of it, left hand {}", object->GetFormID(), object->GetName(), actor->GetFormID(),
				static_cast<const void*>(already ? coming : going), count, left);
			equip->EquipObject(actor.get(), object, already ? coming : going, count, HandOf(*object, left), false, false, true, true);
		} else {
			IR_BRACKET("unequip {:08X} {} from {:08X}, list {}, {} of it, left hand {}", object->GetFormID(), object->GetName(), actor->GetFormID(),
				static_cast<const void*>(coming), count, left);
			equip->UnequipObject(actor.get(), object, coming, count, HandOf(*object, left), false, true, true, true);
		}
		// The game sends its event of equipping within the call. What it didn't answer by now it refused, and a later
		// equip of the same item by the AI or a script mustn't pass for the player's choice
		std::size_t refused = 0;
		{
			const std::scoped_lock lock{ choicesLock };
			refused = std::erase_if(asked, [&](const Choice& a_choice) { return a_choice.at == now; });
		}
		logger::info("{} {} {} {}{}", a_on ? "put" : "took", object->GetName(), a_on ? "on" : "off", actor->GetName(),
			refused > 0 ? std::format(", the game refused {} of {}", refused, inTheWay.size() + (moves ? 2 : 1)) : "");
		// a piece of the outfit the new one pushed off gets its row in the fill below
		Reveal(*actor);
		bodyOwed = true;
		rowsOwedByPanel = true;
		rowsOwed = true;
		return true;
	}

	bool RowsOwed()
	{
		return rowsOwed.load();
	}

	bool Use(std::int32_t a_index, RE::FormID a_form)
	{
		const auto shown = RowOfShown("Use", a_index, a_form);
		if (!shown) {
			return false;
		}
		const auto& actor = shown->actor;
		auto* potion = shown->object->As<RE::AlchemyItem>();
		if (!potion || potion->IsPoison()) {
			IR_LOG("Use refused: {:08X} {} is no potion or food, or a poison", shown->object->GetFormID(), shown->object->GetName());
			return false;
		}
		// the copy the row stands for when it has a list of its own, a stolen bottle beside the bought ones
		RE::ExtraDataList* copy = nullptr;
		if (auto* live = LiveEntry(*actor, *potion); live && live->extraLists && shown->row->extraLists && !shown->row->extraLists->empty()) {
			for (auto* own : *live->extraLists) {
				if (own && std::ranges::find(*shown->row->extraLists, own) != shown->row->extraLists->end()) {
					copy = own;
					break;
				}
			}
		}
		const auto before = CountOf(*actor, *potion);
		IR_BRACKET("{:08X} {} uses {:08X} {}, list {}", actor->GetFormID(), actor->GetName(), potion->GetFormID(), potion->GetName(), static_cast<const void*>(copy));
		{
			const ChangedBy::Ours ours{ actor->GetFormID() };
			RE::ActorEquipManager::GetSingleton()->EquipObject(actor.get(), potion, copy, 1, nullptr, false, true, true, true);
		}
		const auto after = CountOf(*actor, *potion);
		logger::info("{} used {}, {} of it before and {} after", actor->GetName(), potion->GetName(), before, after);
		rowsOwedByPanel = true;
		rowsOwed = true;
		return after < before;
	}

	std::vector<Piece> Outfit()
	{
		std::vector<Piece> pieces;
		const auto actor = Get();
		auto* changes = actor && Other() ? actor->GetInventoryChanges() : nullptr;
		if (!changes || !changes->entryList) {
			return pieces;
		}
		// The game puts its worn mark back on an outfit's piece when the inventory changes, also where a piece the
		// panel keeps on holds the place. What the body carries is the truth, the doll is a copy of it. A piece hidden
		// on them is worn and off the body
		std::set<const RE::TESForm*> onBody;
		if (const auto& biped = actor->GetBiped(false)) {
			for (const auto& object : biped->objects) {
				if (object.item) {
					onBody.insert(object.item);
				}
			}
		}
		for (auto* entry : *changes->entryList) {
			if (!entry || !entry->object || !entry->extraLists || (!onBody.empty() && !onBody.contains(entry->object) && !Hidden::Hides(*actor, entry->object))) {
				continue;
			}
			for (auto* list : *entry->extraLists) {
				if (list && Worn(*list) && list->HasType(RE::ExtraDataType::kOutfitItem)) {
					pieces.push_back({ entry->object, list->HasType(RE::ExtraDataType::kWorn), list->HasType(RE::ExtraDataType::kWornLeft) });
				}
			}
		}
		return pieces;
	}

	bool TakeOffPiece(RE::FormID a_form)
	{
		const auto actor = Get();
		if (!actor || !Other() || !actor->Is3DLoaded() || ReadOnly()) {
			IR_LOG("TakeOffPiece refused: {}", !actor || !Other() ? "no follower is shown" : (!actor->Is3DLoaded() ? "the one shown has no body loaded" : "a mod keeps the one shown read only"));
			return false;
		}
		auto* object = RE::TESForm::LookupByID<RE::TESBoundObject>(a_form);
		auto* live = object ? LiveEntry(*actor, *object) : nullptr;
		RE::ExtraDataList* worn = nullptr;
		if (live && live->extraLists) {
			for (auto* copy : *live->extraLists) {
				if (copy && Worn(*copy) && copy->HasType(RE::ExtraDataType::kOutfitItem)) {
					worn = copy;
					break;
				}
			}
		}
		if (!worn) {
			IR_LOG("TakeOffPiece refused: {:08X} is no worn piece of the outfit of {:08X}", a_form, actor->GetFormID());
			return false;
		}
		const bool left = worn->HasType(RE::ExtraDataType::kWornLeft) && object->Is(RE::FormType::Weapon);
		const auto now = Clock::now();
		{
			const std::scoped_lock lock{ choicesLock };
			asked.push_back({ a_form, false, now, left });
		}
		{
			const ChangedBy::Ours ours{ actor->GetFormID() };
			IR_BRACKET("unequip {:08X} {} of the outfit from {:08X}, list {}", a_form, object->GetName(), actor->GetFormID(), static_cast<const void*>(worn));
			RE::ActorEquipManager::GetSingleton()->UnequipObject(actor.get(), object, worn, 1, HandOf(*object, left), false, true, true, true);
		}
		bool refused = false;
		{
			const std::scoped_lock lock{ choicesLock };
			refused = std::erase_if(asked, [&](const Choice& a_choice) { return a_choice.at == now; }) > 0;
		}
		logger::info("took {} of the outfit off {}{}", object->GetName(), actor->GetName(), refused ? ", the game refused" : "");
		Reveal(*actor);
		bodyOwed = true;
		rowsOwedByPanel = true;
		rowsOwed = true;
		return !refused;
	}
}
