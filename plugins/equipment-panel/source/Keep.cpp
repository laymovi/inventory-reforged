#include "PCH.h"

#include "Keep.h"

#include "ChangedBy.h"
#include "Detour.h"
#include "Settings.h"
#include "Subject.h"
#include "WeaponGrip.h"

namespace Keep
{
	namespace
	{
		using Clock = std::chrono::steady_clock;

		// 2 adds the followers whose outfit copies lost the mark
		constexpr std::uint32_t kVersion = 2;
		constexpr std::size_t kMostActors = 64;
		constexpr std::size_t kMostPieces = 32;
		constexpr std::size_t kMostOutfits = 8;
		// a change by someone else settles this long before the choice goes back, a script that dresses in a few steps
		// is done by then
		constexpr auto kSettle = 1s;
		// a piece changed back this soon after it went back is a fight for it, after this many in a row the panel leaves
		// that piece. Follower mods dress by place on a timer of their own, Ashe's sets her city outfit every 14 s
		constexpr auto kFightWindow = 10min;
		constexpr int kFightsToLeave = 3;
		// the game dresses a body in its outfit as the body loads, a door or a load does that and it's no fight
		constexpr auto kLoadDressing = 5s;
		constexpr RE::FormID kLeftHand = 0x13F43;
		constexpr RE::FormID kRightHand = 0x13F42;

		// with the panel, its followers or the keeping switched off nothing is held, a change of gear then is no fight
		bool Working()
		{
			const auto& settings = Settings::Get();
			return settings.panel && settings.followers && settings.keepChoices;
		}

		// the main thread's last frame found the keeping off, once it's on again the choices go back
		bool wasOff = false;

		struct On
		{
			RE::FormID form;
			bool left;
			// the follower doesn't carry it now and the log said so, it stays chosen and goes on once it's back
			bool away = false;
		};

		// when a kept piece last went back and how many times running it was changed back soon after
		struct Fight
		{
			Clock::time_point restoredAt{};
			int count = 0;
		};

		struct Kept
		{
			std::vector<On> on;
			std::vector<RE::FormID> off;
			std::optional<Clock::time_point> owedSince;
			// the round owed now counts for no fight, the game dressed a loading body
			bool excused = false;
			Clock::time_point loadedAt{};
			std::unordered_map<RE::FormID, Fight> fights;
			// how many times the player chose for them, a restore on a copy writes back only while no choice came between
			std::uint32_t choices = 0;
			// what a save of an older build left on them was mended since the game loaded
			bool repaired = false;
		};

		std::mutex keptLock;
		std::unordered_map<RE::FormID, Kept> kept;
		std::atomic<bool> any{ false };
		// the actor whose gear the panel puts back right now, its own equip events are no change by someone else
		std::atomic<RE::FormID> restoring{ 0 };
		// the same on this thread inside the game's re-dress, which runs on the game's job threads too
		thread_local RE::FormID puttingBack = 0;
		// the follower the game re-dresses on this thread, 0 for none
		thread_local RE::FormID redressing = 0;
		// the follower whose worn marks this thread took off last, their outfit is the next step of the re-dress
		thread_local RE::FormID stripped = 0;

		// the outfits whose copies lost the mark on each follower, read by the game's re-dress on its job threads too
		std::mutex revealedLock;
		std::unordered_map<RE::FormID, std::vector<RE::FormID>> revealed;
		std::set<std::pair<RE::FormID, RE::FormID>> setsTold;

		bool Gear(const RE::TESForm* a_form)
		{
			return a_form && (a_form->Is(RE::FormType::Armor) || a_form->Is(RE::FormType::Weapon) || a_form->Is(RE::FormType::Ammo) || a_form->Is(RE::FormType::Light));
		}

		std::uint32_t Parts(const RE::TESForm* a_form)
		{
			const auto* armor = a_form ? a_form->As<RE::TESObjectARMO>() : nullptr;
			return armor && !armor->IsShield() ? armor->GetSlotMask().underlying() : 0;
		}

		using WeaponGrip::BothHands;

		// what a hand holds: a weapon in its hand, a shield or a torch in the left one
		bool InLeft(const RE::TESForm* a_form, bool a_left)
		{
			const auto* armor = a_form ? a_form->As<RE::TESObjectARMO>() : nullptr;
			return (armor && armor->IsShield()) || (a_form && a_form->Is(RE::FormType::Light)) || (a_form && a_form->Is(RE::FormType::Weapon) && a_left);
		}

		bool Held(const RE::TESForm* a_form)
		{
			const auto* armor = a_form ? a_form->As<RE::TESObjectARMO>() : nullptr;
			return (armor && armor->IsShield()) || (a_form && (a_form->Is(RE::FormType::Weapon) || a_form->Is(RE::FormType::Light)));
		}

		constexpr std::uint8_t kRightHandBit = 1;
		constexpr std::uint8_t kLeftHandBit = 2;

		// the hands a piece takes, both for a weapon of both hands, the left for a shield or a torch
		std::uint8_t HandsOf(const RE::TESForm* a_form, bool a_left)
		{
			if (!Held(a_form)) {
				return 0;
			}
			if (BothHands(a_form)) {
				return kRightHandBit | kLeftHandBit;
			}
			return InLeft(a_form, a_left) ? kLeftHandBit : kRightHandBit;
		}

		// Whether the hand of a piece held there really holds it, a weapon of both hands in either. A worn
		// mark alone holds nothing
		bool InHand(const RE::Actor& a_actor, const RE::TESForm& a_object, bool a_left)
		{
			if (BothHands(&a_object)) {
				return a_actor.GetEquippedObject(false) == &a_object || a_actor.GetEquippedObject(true) == &a_object;
			}
			return a_actor.GetEquippedObject(InLeft(&a_object, a_left)) == &a_object;
		}

		// whether two pieces on would take the same place: body slots for armor, a hand for what is held, ammo for ammo
		bool SamePlace(const On& a_one, const On& a_other)
		{
			const auto* one = RE::TESForm::LookupByID(a_one.form);
			const auto* other = RE::TESForm::LookupByID(a_other.form);
			if (!one || !other) {
				return false;
			}
			if (one->Is(RE::FormType::Ammo) || other->Is(RE::FormType::Ammo)) {
				return one->Is(RE::FormType::Ammo) && other->Is(RE::FormType::Ammo);
			}
			if (Held(one) && Held(other)) {
				return BothHands(one) || BothHands(other) || InLeft(one, a_one.left) == InLeft(other, a_other.left);
			}
			return (Parts(one) & Parts(other)) != 0;
		}

		RE::InventoryEntryData* Entry(RE::Actor& a_actor, const RE::TESBoundObject& a_object)
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

		std::int32_t Count(RE::Actor& a_actor, RE::TESBoundObject& a_object)
		{
			const auto counts = a_actor.GetInventory([&](RE::TESBoundObject& a_item) { return &a_item == &a_object; });
			const auto found = counts.find(&a_object);
			return found != counts.end() ? found->second.first : 0;
		}

		// Whether they carry any of it, the base container's count and the change of it, with no map built the way
		// GetInventory builds one. The combat score asks it for each entry
		bool Carries(RE::Actor& a_actor, const RE::TESBoundObject& a_object)
		{
			auto* changes = a_actor.GetInventoryChanges();
			return changes && changes->GetCount(&a_object, [](const RE::InventoryEntryData*) { return true; }) > 0;
		}

		bool WornIn(const RE::ExtraDataList& a_list, bool a_left)
		{
			return a_list.HasType(a_left ? RE::ExtraDataType::kWornLeft : RE::ExtraDataType::kWorn);
		}

		bool Worn(const RE::ExtraDataList& a_list)
		{
			return a_list.HasType(RE::ExtraDataType::kWorn) || a_list.HasType(RE::ExtraDataType::kWornLeft);
		}

		const RE::BGSEquipSlot* HandOf(const RE::TESBoundObject& a_object, bool a_left)
		{
			return a_object.Is(RE::FormType::Weapon) ? RE::TESForm::LookupByID<RE::BGSEquipSlot>(a_left ? kLeftHand : kRightHand) : nullptr;
		}

		// the copy that is worn where the choice wants it, and one that isn't worn at all
		std::pair<RE::ExtraDataList*, RE::ExtraDataList*> Copies(RE::InventoryEntryData* a_entry, bool a_weapon, bool a_left)
		{
			RE::ExtraDataList* worn = nullptr;
			RE::ExtraDataList* free = nullptr;
			if (a_entry && a_entry->extraLists) {
				for (auto* list : *a_entry->extraLists) {
					if (!list) {
						continue;
					}
					if (a_weapon ? WornIn(*list, a_left) : Worn(*list)) {
						worn = worn ? worn : list;
					} else if (!Worn(*list)) {
						free = free ? free : list;
					}
				}
			}
			return { worn, free };
		}

		// A weapon of both hands worn other than a_besides, with either mark it holds both hands
		std::pair<RE::TESBoundObject*, RE::ExtraDataList*> BothHandsWorn(RE::Actor& a_actor, const RE::TESBoundObject& a_besides)
		{
			auto* changes = a_actor.GetInventoryChanges();
			if (!changes || !changes->entryList) {
				return {};
			}
			for (auto* entry : *changes->entryList) {
				if (!entry || entry->object == &a_besides || !BothHands(entry->object) || !entry->extraLists) {
					continue;
				}
				for (auto* list : *entry->extraLists) {
					if (list && Worn(*list)) {
						return { entry->object, list };
					}
				}
			}
			return {};
		}

		// What a save of an older build may hold, mended once per follower after a load before their first restore.
		// Nothing they really wear of the player's choice comes off, nothing is added or taken away
		void Repair(RE::Actor& a_actor, Kept& a_kept)
		{
			// a piece pushed off by a new one was held off for good. The piece kept on in its place
			// pushes it again anyway
			std::erase_if(a_kept.off, [&](RE::FormID a_form) {
				const auto place = std::ranges::find_if(a_kept.on, [&](const On& a_on) { return SamePlace(On{ a_form, false }, a_on); });
				if (place == a_kept.on.end()) {
					return false;
				}
				const auto* off = RE::TESForm::LookupByID(a_form);
				const auto* on = RE::TESForm::LookupByID(place->form);
				logger::info("{} is held off {} no more, {} kept on takes its place", off ? off->GetName() : "", a_actor.GetName(), on ? on->GetName() : "");
				return true;
			});
			// Two pieces marked worn in hands that hold one, the force flag left the game's own swap half done. The other
			// loses its mark beside a piece kept on, the restore right after puts that one in its hand when the mark
			// alone held nothing. A pair of pieces not kept leaves the one the hands hold, a pair it can't tell apart is
			// left as it is
			struct Marked
			{
				RE::TESBoundObject* object;
				RE::ExtraDataList* list;
				std::uint8_t hands;
			};
			std::vector<Marked> marked;
			if (auto* changes = a_actor.GetInventoryChanges(); changes && changes->entryList) {
				for (auto* entry : *changes->entryList) {
					if (!entry || !Held(entry->object) || !entry->extraLists) {
						continue;
					}
					const bool oneHand = entry->object->Is(RE::FormType::Weapon) && !BothHands(entry->object);
					for (auto* list : *entry->extraLists) {
						if (list && Worn(*list)) {
							const auto marks = static_cast<std::uint8_t>((WornIn(*list, false) ? kRightHandBit : 0) | (WornIn(*list, true) ? kLeftHandBit : 0));
							marked.push_back({ entry->object, list, oneHand ? marks : HandsOf(entry->object, false) });
						}
					}
				}
			}
			const auto keptOn = [&](const Marked& a_piece) {
				return std::ranges::any_of(a_kept.on, [&](const On& a_on) { return a_on.form == a_piece.object->GetFormID(); });
			};
			const auto holds = [&](const Marked& a_piece) {
				return a_actor.GetEquippedObject(false) == a_piece.object || a_actor.GetEquippedObject(true) == a_piece.object;
			};
			auto* equip = RE::ActorEquipManager::GetSingleton();
			for (std::size_t first = 0; first < marked.size(); ++first) {
				for (std::size_t second = first + 1; second < marked.size(); ++second) {
					auto& one = marked[first];
					auto& other = marked[second];
					if (!one.list || !other.list || one.object == other.object || (one.hands & other.hands) == 0) {
						continue;
					}
					Marked* stale = nullptr;
					if (keptOn(one) != keptOn(other)) {
						stale = keptOn(one) ? &other : &one;
					} else if (holds(one) != holds(other)) {
						stale = holds(one) ? &other : &one;
					}
					if (!stale) {
						continue;
					}
					const auto& stays = stale == &one ? other : one;
					IR_BRACKET("unequip {:08X} {} from {:08X}, a stale mark beside {:08X}, list {}", stale->object->GetFormID(), stale->object->GetName(), a_actor.GetFormID(),
						stays.object->GetFormID(), static_cast<const void*>(stale->list));
					equip->UnequipObject(&a_actor, stale->object, stale->list, 1, HandOf(*stale->object, WornIn(*stale->list, true)), false, true, false, true);
					logger::info("{} lost its worn mark on {}, {} holds that hand, a save of an older build left both", stale->object->GetName(), a_actor.GetName(), stays.object->GetName());
					stale->list = nullptr;
				}
			}
			// An older build put the player's choice on with the force flag. The game keeps it on the copy as
			// ExtraCannotWear, EquipObject (38894, 37938) adds it with force and lifts it without (11615, 11469), and puts
			// a copy carrying it on only with force. Lifted from the pieces kept on, they stay worn
			for (const auto& on : a_kept.on) {
				auto* object = RE::TESForm::LookupByID<RE::TESBoundObject>(on.form);
				auto* entry = object ? Entry(a_actor, *object) : nullptr;
				if (!entry || !entry->extraLists) {
					continue;
				}
				for (auto* list : *entry->extraLists) {
					if (list && list->HasType(RE::ExtraDataType::kCannotWear)) {
						list->RemoveByType(RE::ExtraDataType::kCannotWear);
						logger::info("{} on {} lost the force flag an older build put on it", object->GetName(), a_actor.GetName());
					}
				}
			}
		}

		// Puts the follower's gear back the way the player chose it. A piece changed back again soon after it last went
		// back is one more fight for it, the piece another mod wins each time is let go and the rest stay kept
		void Restore(RE::Actor& a_actor, Kept& a_kept, Clock::time_point a_now)
		{
			auto* equip = RE::ActorEquipManager::GetSingleton();
			restoring = a_actor.GetFormID();
			const ChangedBy::Ours ours{ a_actor.GetFormID() };
			if (!std::exchange(a_kept.repaired, true)) {
				Repair(a_actor, a_kept);
			}
			const auto goesBack = [&](RE::FormID a_form, const RE::TESBoundObject& a_object) {
				auto& fight = a_kept.fights[a_form];
				if (!a_kept.excused) {
					const bool soon = fight.restoredAt != Clock::time_point{} && a_now - fight.restoredAt < kFightWindow;
					fight.count = soon ? fight.count + 1 : 0;
					if (fight.count >= kFightsToLeave) {
						const auto by = ChangedBy::Last(a_actor.GetFormID(), a_form);
						logger::warn("{} changes {} on {} back each time, the panel leaves it until the player chooses again", by ? by->by : "another mod"s, a_object.GetName(),
							a_actor.GetName());
						a_kept.fights.erase(a_form);
						return false;
					}
				}
				fight.restoredAt = a_now;
				return true;
			};
			std::erase_if(a_kept.off, [&](RE::FormID a_form) {
				auto* object = RE::TESForm::LookupByID<RE::TESBoundObject>(a_form);
				auto* entry = object ? Entry(a_actor, *object) : nullptr;
				if (!entry || !entry->extraLists) {
					return false;
				}
				for (auto* list : *entry->extraLists) {
					if (list && Worn(*list)) {
						if (!goesBack(a_form, *object)) {
							return true;
						}
						const bool left = list->HasType(RE::ExtraDataType::kWornLeft);
						const auto count = static_cast<std::uint32_t>(object->Is(RE::FormType::Ammo) ? std::max<std::int32_t>(list->GetCount(), 1) : 1);
						IR_BRACKET("unequip {:08X} {} from {:08X} the way the player chose, list {}", a_form, object->GetName(), a_actor.GetFormID(), static_cast<const void*>(list));
						equip->UnequipObject(&a_actor, object, list, count, HandOf(*object, left), false, true, false, true);
						logger::info("{} went back off {}, the player took it off", object->GetName(), a_actor.GetName());
						return false;
					}
				}
				return false;
			});
			// A piece that left the follower stays chosen and goes back on once it's back: a mod took it into its own chest
			// and gave it back, a disarm dropped the sword and they picked it up. Its leaving is no fight and starts its
			// count anew, the log tells it once
			std::vector<RE::FormID> away;
			std::erase_if(a_kept.on, [&](const On& a_on) {
				auto* object = RE::TESForm::LookupByID<RE::TESBoundObject>(a_on.form);
				if (!object) {
					logger::info("{:08X} is gone from the game, the panel doesn't keep it on {}", a_on.form, a_actor.GetName());
					a_kept.fights.erase(a_on.form);
					return true;
				}
				if (Count(a_actor, *object) <= 0) {
					if (!a_on.away) {
						logger::info("{} is away from {}, it goes back on when it's back", object->GetName(), a_actor.GetName());
						a_kept.fights.erase(a_on.form);
					}
					away.push_back(a_on.form);
					return false;
				}
				const bool oneHand = object->Is(RE::FormType::Weapon) && !BothHands(object);
				const bool hand = Held(object);
				auto* entry = Entry(a_actor, *object);
				const auto [worn, free] = Copies(entry, oneHand, a_on.left);
				// what a hand holds is off while another weapon of both hands is worn, whatever its own mark says, and while
				// its hand holds something else
				const auto [both, bothList] = hand ? BothHandsWorn(a_actor, *object) : std::pair<RE::TESBoundObject*, RE::ExtraDataList*>{};
				if (worn && !both && (!hand || InHand(a_actor, *object, a_on.left))) {
					if (a_on.away) {
						logger::info("{} is back on {}, it went on as it came back", object->GetName(), a_actor.GetName());
					}
					return false;
				}
				if (!goesBack(a_on.form, *object)) {
					return true;
				}
				if (both) {
					IR_BRACKET("unequip {:08X} {} from {:08X}, it holds both hands where the player chose {:08X}, list {}", both->GetFormID(), both->GetName(),
						a_actor.GetFormID(), a_on.form, static_cast<const void*>(bothList));
					equip->UnequipObject(&a_actor, both, bothList, 1, HandOf(*both, bothList->HasType(RE::ExtraDataType::kWornLeft)), false, true, false, true);
					logger::info("{} went off {}, it held both hands where the player chose {}", both->GetName(), a_actor.GetName(), object->GetName());
				}
				const auto count = static_cast<std::uint32_t>(object->Is(RE::FormType::Ammo) ? std::max<std::int32_t>(Count(a_actor, *object), 1) : 1);
				auto* going = worn ? worn : free;
				// a worn mark its hand doesn't hold comes off first, the game's equip of a marked copy does nothing. Once a
				// round, a piece the game won't put in the hand counts its fights like any other
				if (worn && hand && !InHand(a_actor, *object, a_on.left)) {
					IR_BRACKET("unequip {:08X} {} from {:08X}, its worn mark held nothing, list {}", a_on.form, object->GetName(), a_actor.GetFormID(), static_cast<const void*>(worn));
					equip->UnequipObject(&a_actor, object, worn, 1, HandOf(*object, WornIn(*worn, true)), false, true, false, true);
					logger::info("{} was marked worn on {} and no hand held it, the mark comes off", object->GetName(), a_actor.GetName());
					going = Copies(Entry(a_actor, *object), oneHand, a_on.left).second;
				}
				IR_BRACKET("equip {:08X} {} on {:08X} the way the player chose, list {}", a_on.form, object->GetName(), a_actor.GetFormID(), static_cast<const void*>(going));
				equip->EquipObject(&a_actor, object, going, count, HandOf(*object, a_on.left), false, false, false, true);
				logger::info("{} went back on {}, the player put it on", object->GetName(), a_actor.GetName());
				return false;
			});
			for (auto& on : a_kept.on) {
				on.away = std::ranges::find(away, on.form) != away.end();
			}
			restoring = 0;
		}

		bool ItemMenuOpen()
		{
			auto* ui = RE::UI::GetSingleton();
			return ui->IsMenuOpen(RE::InventoryMenu::MENU_NAME) || ui->IsMenuOpen(RE::ContainerMenu::MENU_NAME) ||
				ui->IsMenuOpen(RE::BarterMenu::MENU_NAME) || ui->IsMenuOpen(RE::GiftMenu::MENU_NAME);
		}

		void Owe(RE::FormID a_actor, bool a_load, bool a_redress)
		{
			const auto now = Clock::now();
			const std::scoped_lock lock{ keptLock };
			const auto found = kept.find(a_actor);
			if (found == kept.end()) {
				return;
			}
			auto& one = found->second;
			if (a_load) {
				one.loadedAt = now;
			}
			// one change of clothes is many equip events, all of one round. A round the game dressed a loading body in
			// is no fight, nor one of its re-dress at an inventory change
			const bool byLoad = now - one.loadedAt < kLoadDressing;
			one.excused = (one.owedSince && one.excused) || byLoad || a_redress;
			one.owedSince = now;
		}

		struct Equips : RE::BSTEventSink<RE::TESEquipEvent>
		{
			RE::BSEventNotifyControl ProcessEvent(const RE::TESEquipEvent* a_event, RE::BSTEventSource<RE::TESEquipEvent>*) override
			{
				if (!any.load() || !a_event || !a_event->actor || a_event->actor->IsPlayerRef() || !Working()) {
					return RE::BSEventNotifyControl::kContinue;
				}
				const auto actor = a_event->actor->GetFormID();
				if (actor == restoring.load() || actor == puttingBack || !Gear(RE::TESForm::LookupByID(a_event->baseObject))) {
					return RE::BSEventNotifyControl::kContinue;
				}
				Owe(actor, false, actor == redressing);
				return RE::BSEventNotifyControl::kContinue;
			}
		};

		// A piece kept on came back to a follower, a gift, a script's AddItem, picked up from the ground. The game's
		// re-dress puts it on in PutBack only when it reaches AddWornOutfit (418622 jumps past it at +0x14C with no
		// default outfit and at +0x24F after its check of the outfit against the worn slots), so a round is owed, one of
		// no fight
		struct Returns : RE::BSTEventSink<RE::TESContainerChangedEvent>
		{
			RE::BSEventNotifyControl ProcessEvent(const RE::TESContainerChangedEvent* a_event, RE::BSTEventSource<RE::TESContainerChangedEvent>*) override
			{
				if (!any.load() || !a_event || a_event->newContainer == 0 || a_event->itemCount <= 0 || !Working()) {
					return RE::BSEventNotifyControl::kContinue;
				}
				bool chosen = false;
				{
					const std::scoped_lock lock{ keptLock };
					const auto found = kept.find(a_event->newContainer);
					chosen = found != kept.end() && std::ranges::any_of(found->second.on, [&](const On& a_on) { return a_on.form == a_event->baseObj; });
				}
				if (chosen) {
					Owe(a_event->newContainer, false, true);
				}
				return RE::BSEventNotifyControl::kContinue;
			}
		};

		// the body built anew in a new cell or after a load, the game dresses it in its outfit then
		struct Loads : RE::BSTEventSink<RE::TESObjectLoadedEvent>
		{
			RE::BSEventNotifyControl ProcessEvent(const RE::TESObjectLoadedEvent* a_event, RE::BSTEventSource<RE::TESObjectLoadedEvent>*) override
			{
				if (any.load() && a_event && a_event->loaded && Working()) {
					Owe(a_event->formID, true, false);
				}
				return RE::BSEventNotifyControl::kContinue;
			}
		};

		// The combat AI picks what its fighter holds by the score of each entry of the fight's inventory, a virtual of
		// each kind of entry at slot 0x0C, CalculateScore(controller) in CommonLib. Read from the game files of 1.7.104
		// and 1.6.1170 (melee 45015, ranged 45031, shield 45045, one handed block 45054, torch 45065) and of 1.5.97
		// (43796, 43812, 43826, 43835, 43846). The block's returns the entry's score at +0x18, the others take the
		// fighter from the controller's handle at +0x28 and return a float, and the base class has its pure stub there.
		// Spells and staves come through the 30 tables of CombatInventoryItemMagicT of Magic and of Staff, one per kind
		// of caster, all with 45082 there (43863 on 1.5.97), which takes the entry's own range and kind and hands them
		// to 45084 with the controller the way the ranged score does. The staff's own table of CommonLib is abstract.
		// An entry scored 0 isn't chosen
		constexpr std::size_t kScoreSlot = 0x0C;
		using Score = float (*)(RE::CombatInventoryItem*, RE::CombatController*);
		// the score each hooked table had before, by the table's place. Filled as the data loads, before the first
		// fight, and only read after
		std::unordered_map<std::uintptr_t, Score> scores;
		constexpr RE::FormID kBothHands = 0x13F45;

		// the hands a spell's entry takes, the one of its equip slot. A staff's entry holds the staff and goes by it
		std::uint8_t SlotHands(const RE::BGSEquipSlot* a_slot)
		{
			static const auto* left = RE::TESForm::LookupByID<RE::BGSEquipSlot>(kLeftHand);
			static const auto* right = RE::TESForm::LookupByID<RE::BGSEquipSlot>(kRightHand);
			static const auto* both = RE::TESForm::LookupByID<RE::BGSEquipSlot>(kBothHands);
			if (a_slot && a_slot == both) {
				return kRightHandBit | kLeftHandBit;
			}
			return a_slot && a_slot == left ? kLeftHandBit : (a_slot && a_slot == right ? kRightHandBit : 0);
		}

		// An entry the AI may not choose for a follower: it takes a hand a piece kept on holds and isn't that piece, or
		// the player took it off. A spell is cast from the other hand. A piece kept on they don't carry now holds no hand,
		// a disarmed follower fights with what they have until they pick it up. Any other fighter costs a lookup of their
		// form id
		bool Shut(RE::CombatInventoryItem& a_item, RE::CombatController& a_controller)
		{
			// the cached actor pointer beside the handle crashed Follower Tactics on a cave bear, the handle is checked
			if (!a_item.item || !a_controller.inventory || a_controller.inventory->parentController != &a_controller) {
				return false;
			}
			const auto actor = a_controller.attackerHandle.get();
			if (!actor) {
				return false;
			}
			std::vector<On> on;
			std::vector<RE::FormID> off;
			{
				const std::scoped_lock lock{ keptLock };
				const auto found = kept.find(actor->GetFormID());
				if (found == kept.end()) {
					return false;
				}
				on = found->second.on;
				off = found->second.off;
			}
			if (Subject::ReadOnlyActor(actor->GetFormID())) {
				return false;
			}
			const auto form = a_item.item->GetFormID();
			if (std::ranges::find(off, form) != off.end()) {
				return true;
			}
			// the entry's equip slot is the pointer at +0x20, the melee score of 1.5.97 and 1.7.104 compares it with the
			// left hand's
			static const auto* left = RE::TESForm::LookupByID<RE::BGSEquipSlot>(kLeftHand);
			const auto* slot = a_item.itemSlot.equipSlot;
			const auto takes = Held(a_item.item) ? HandsOf(a_item.item, slot == left) : SlotHands(slot);
			// the count last, only for a piece of the same hands
			return std::ranges::any_of(on, [&](const On& a_on) {
				const auto* object = a_on.form != form ? RE::TESForm::LookupByID<RE::TESBoundObject>(a_on.form) : nullptr;
				return object && (HandsOf(object, a_on.left) & takes) != 0 && Carries(*actor, *object);
			});
		}

		float Scored(RE::CombatInventoryItem* a_item, RE::CombatController* a_controller)
		{
			const auto found = a_item ? scores.find(*reinterpret_cast<const std::uintptr_t*>(a_item)) : scores.end();
			if (found == scores.end()) {
				return a_item ? a_item->itemScore : 0.0F;
			}
			const float score = found->second(a_item, a_controller);
			return score > 0.0F && any.load() && Working() && a_controller && Shut(*a_item, *a_controller) ? 0.0F : score;
		}

		// A slot that holds the score read there, or another plugin's hook of it, which goes first. Anything else stays
		// as it is and the log says so
		bool HookScore(REL::VariantID a_table, REL::RelocationID a_score, std::string_view a_kind)
		{
			REL::Relocation<std::uintptr_t> table{ a_table };
			const auto held = *reinterpret_cast<const std::uintptr_t*>(table.address() + kScoreSlot * sizeof(std::uintptr_t));
			HMODULE module = nullptr;
			const bool plugin = GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, reinterpret_cast<LPCWSTR>(held), &module) &&
			                    reinterpret_cast<std::uintptr_t>(module) != REL::Module::get().base();
			if (held != REL::Relocation<std::uintptr_t>{ a_score }.address() && !plugin) {
				logger::warn("the combat AI's score of {} isn't where it was read on 1.5.97, 1.6.1170 and 1.7.104, in a fight a follower may take up {} against the player's choice",
					a_kind, a_kind);
				return false;
			}
			if (plugin) {
				logger::info("another plugin scores {} for the combat AI, the player's choices go over its answer", a_kind);
			}
			scores.emplace(table.address(), reinterpret_cast<Score>(held));
			table.write_vfunc(kScoreSlot, &Scored);
			return true;
		}

		// the tables of spells and of staves, by kind of caster
		const std::array<REL::VariantID, 30> kMagicTables{
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterOffensive_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterOffensive_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterRestore_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterRestore_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterWard_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterWard_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterArmor_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterArmor_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterSummon_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterSummon_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterBoundItem_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterBoundItem_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterCloak_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterCloak_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterInvisibility_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterInvisibility_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterLight_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterLight_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterDisarm_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterDisarm_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterParalyze_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterParalyze_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterReanimate_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterReanimate_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterStagger_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterStagger_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterTargetEffect_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterTargetEffect_[0],
			RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemMagic_CombatMagicCasterScript_[0], RE::VTABLE_CombatInventoryItemMagicT_CombatInventoryItemStaff_CombatMagicCasterScript_[0]
		};

		// The game re-dresses a follower whenever their inventory changes, a gift, arrows, a script's AddItem. One
		// function does it (418622 of 1.7.104 and 1.6.1170, 24234 of 1.5.97): its best weapon (+0x71C, +0x68A on
		// 1.5.97) and best armor (+0x310, +0x27F) through EquipObject, and the outfit through AddWornOutfit (+0x25E,
		// +0x1C3), which puts each piece on with EquipObject at +0xFF. A script's EquipItem goes another way, its
		// SetOutfit reaches the piece hook with no re-dress running, both stay untouched
		constexpr REL::RelocationID kRedress{ 24234, 418622 };
		constexpr REL::VariantOffset kBestWeapon{ 0x68A, 0x71C, 0 };
		constexpr REL::VariantOffset kBestArmor{ 0x27F, 0x310, 0 };
		constexpr REL::VariantOffset kOutfitCall{ 0x1C3, 0x25E, 0 };
		constexpr REL::RelocationID kAddWornOutfit{ 19266, 19692 };
		constexpr REL::VariantOffset kOutfitPiece{ 0xFF, 0xFF, 0 };
		constexpr REL::RelocationID kEquipObject{ 37938, 38894 };
		constexpr REL::VariantOffset kStripCall{ 0xFB, 0xF3, 0 };
		constexpr REL::RelocationID kStrip{ 15860, 16100 };
		// InventoryChanges::InitOutfitItems. The re-dress calls it when no copy carries the outfit's mark (19691 at +0x15B,
		// 19265 on 1.5.97), SPID 7 stubs that check and calls it itself, so the gate is at its start: sub rsp, 0x48 and
		// test rdx, rdx, the same on 1.7.104 and 1.5.97
		constexpr REL::RelocationID kNewSet{ 15833, 16072 };
		constexpr std::array<std::uint8_t, 7> kNewSetStart{ 0x48, 0x83, 0xEC, 0x48, 0x48, 0x85, 0xD2 };
		constexpr std::uint8_t kCall = 0xE8;
		constexpr std::size_t kCallSize = 5;

		std::set<std::pair<RE::FormID, RE::FormID>> refusalsTold;

		// whether the actor still carries a piece kept on, one a mod took away holds no place
		bool Carried(RE::Actor& a_actor, const On& a_on)
		{
			auto* object = RE::TESForm::LookupByID<RE::TESBoundObject>(a_on.form);
			return object && Count(a_actor, *object) > 0;
		}

		// The game's own re-dress puts nothing where a piece kept on is, unless it's that piece, and no piece kept off.
		// A follower Keep doesn't know costs a lookup of their form id
		bool Refused(RE::Actor* a_actor, RE::TESBoundObject* a_object, const RE::BGSEquipSlot* a_slot)
		{
			if (!a_actor || !a_object || !any.load() || !Working()) {
				return false;
			}
			std::vector<On> on;
			bool off = false;
			{
				const std::scoped_lock lock{ keptLock };
				const auto found = kept.find(a_actor->GetFormID());
				if (found == kept.end()) {
					return false;
				}
				on = found->second.on;
				off = std::ranges::find(found->second.off, a_object->GetFormID()) != found->second.off.end();
			}
			if (Subject::ReadOnlyActor(a_actor->GetFormID())) {
				return false;
			}
			static const auto* left = RE::TESForm::LookupByID<RE::BGSEquipSlot>(kLeftHand);
			const On going{ a_object->GetFormID(), a_slot && a_slot == left };
			const auto place = std::ranges::find_if(on, [&](const On& a_on) { return a_on.form != going.form && SamePlace(going, a_on) && Carried(*a_actor, a_on); });
			if (!off && place == on.end()) {
				return false;
			}
			bool first = false;
			{
				const std::scoped_lock lock{ keptLock };
				first = refusalsTold.emplace(a_actor->GetFormID(), going.form).second;
			}
			if (first) {
				const auto* holder = place != on.end() ? RE::TESForm::LookupByID(place->form) : nullptr;
				logger::info("the game's re-dress of {} leaves {} off, {}", a_actor->GetName(), a_object->GetName(),
					holder ? std::format("{} the player chose holds its place", holder->GetName()) : std::string("the player took it off"));
			}
			return true;
		}

		// The re-dress first takes every worn mark off (16100 at +0xF3, 15860 at +0xFB on 1.5.97, through 16067 that
		// spares only a copy carrying the force flag). The player's choice goes back on before the outfit, with the
		// flags of the game's own calls there, and the gate keeps the outfit and the best gear out of its places.
		// Copied under the lock, the equips go with it let go
		void PutBack(RE::Actor& a_actor, bool a_hands)
		{
			std::vector<On> on;
			{
				const std::scoped_lock lock{ keptLock };
				const auto found = kept.find(a_actor.GetFormID());
				if (found == kept.end()) {
					return;
				}
				on = found->second.on;
			}
			if (!Working() || Subject::ReadOnlyActor(a_actor.GetFormID())) {
				return;
			}
			auto* equip = RE::ActorEquipManager::GetSingleton();
			const auto before = std::exchange(puttingBack, a_actor.GetFormID());
			// inside a script's SetOutfit the choice going back on is still the panel's
			const ChangedBy::Ours ours{ a_actor.GetFormID() };
			for (const auto& piece : on) {
				auto* object = RE::TESForm::LookupByID<RE::TESBoundObject>(piece.form);
				const auto count = object ? Count(a_actor, *object) : 0;
				if (count <= 0) {
					continue;
				}
				if (Held(object) && !a_hands) {
					continue;
				}
				const bool oneHand = object->Is(RE::FormType::Weapon) && !BothHands(object);
				const auto [worn, free] = Copies(Entry(a_actor, *object), oneHand, piece.left);
				if (worn) {
					continue;
				}
				IR_BRACKET("equip {:08X} {} on {:08X} again before the game's outfit, list {}", piece.form, object->GetName(), a_actor.GetFormID(), static_cast<const void*>(free));
				equip->EquipObject(&a_actor, object, free, object->Is(RE::FormType::Ammo) ? static_cast<std::uint32_t>(count) : 1, HandOf(*object, piece.left), false, false, false, false);
			}
			puttingBack = before;
		}

		// the strip, its events are the game's re-dress and count for no fight
		struct Strip
		{
			static void thunk(RE::InventoryChanges* a_changes)
			{
				const auto before = std::exchange(redressing, a_changes && a_changes->owner ? a_changes->owner->GetFormID() : 0);
				original(a_changes);
				redressing = before;
				stripped = a_changes && a_changes->owner ? a_changes->owner->GetFormID() : 0;
				// Armor goes back here and not at the outfit's call, the game can jump past that one and SPID takes it over.
				// The hands wait, a weapon put on this early keeps its worn mark and the hand stays empty
				if (auto* actor = a_changes && a_changes->owner ? a_changes->owner->As<RE::Actor>() : nullptr; actor && any.load()) {
					PutBack(*actor, false);
				}
			}

			static inline REL::Relocation<decltype(thunk)> original;
		};

		template <std::size_t Site>
		struct BestEquip
		{
			static void thunk(RE::ActorEquipManager* a_manager, RE::Actor* a_actor, RE::TESBoundObject* a_object, RE::ExtraDataList* a_list, std::uint32_t a_count,
				const RE::BGSEquipSlot* a_slot, bool a_queue, bool a_force, bool a_sounds, bool a_now)
			{
				// the outfit's step is behind, under SPID this is the first place of the re-dress left for the hands
				if (a_actor && stripped == a_actor->GetFormID() && any.load()) {
					PutBack(*a_actor, true);
				}
				stripped = 0;
				if (!Refused(a_actor, a_object, a_slot)) {
					const auto before = std::exchange(redressing, a_actor ? a_actor->GetFormID() : 0);
					original(a_manager, a_actor, a_object, a_list, a_count, a_slot, a_queue, a_force, a_sounds, a_now);
					redressing = before;
				}
			}

			static inline REL::Relocation<decltype(thunk)> original;
		};

		struct WornOutfit
		{
			static void thunk(RE::Actor* a_actor, RE::BGSOutfit* a_outfit, bool a_update)
			{
				if (a_actor && any.load()) {
					PutBack(*a_actor, true);
				}
				const auto before = std::exchange(redressing, a_actor ? a_actor->GetFormID() : 0);
				original(a_actor, a_outfit, a_update);
				redressing = before;
			}

			static inline REL::Relocation<decltype(thunk)> original;
		};

		// a piece of the outfit goes on only while the game re-dresses, a script's SetOutfit comes here too. Under SPID the
		// outfit's call is its own, the strip before it on this thread tells the re-dress
		struct OutfitPiece
		{
			static void thunk(RE::ActorEquipManager* a_manager, RE::Actor* a_actor, RE::TESBoundObject* a_object, RE::ExtraDataList* a_list, std::uint32_t a_count,
				const RE::BGSEquipSlot* a_slot, bool a_queue, bool a_force, bool a_sounds, bool a_now)
			{
				const auto dressed = redressing != 0 ? redressing : stripped;
				if (dressed == 0 || !a_actor || a_actor->GetFormID() != dressed || !Refused(a_actor, a_object, a_slot)) {
					original(a_manager, a_actor, a_object, a_list, a_count, a_slot, a_queue, a_force, a_sounds, a_now);
				}
			}

			static inline REL::Relocation<decltype(thunk)> original;
		};

		bool Bare(RE::FormID a_actor, RE::FormID a_outfit)
		{
			const std::scoped_lock lock{ revealedLock };
			const auto found = revealed.find(a_actor);
			return found != revealed.end() && std::ranges::find(found->second, a_outfit) != found->second.end();
		}

		// A follower whose copies of the outfit all lost the mark carries none marked, so the re-dress would add a whole
		// new set and put it on, free gear for the player each time the pieces come off in a trade, under SPID a whole set
		// on the first gift with no piece of it worn (59 more weight). That outfit gets none, a new outfit a mod sets gets
		// its pieces as the game gives them
		struct NewSet
		{
			static void thunk(RE::InventoryChanges* a_changes, RE::BGSOutfit* a_outfit, std::uint16_t a_level)
			{
				auto* owner = a_changes ? a_changes->owner : nullptr;
				if (!owner || !a_outfit || !Bare(owner->GetFormID(), a_outfit->GetFormID())) {
					original(a_changes, a_outfit, a_level);
					return;
				}
				bool first = false;
				{
					const std::scoped_lock lock{ revealedLock };
					first = setsTold.emplace(owner->GetFormID(), a_outfit->GetFormID()).second;
				}
				if (first) {
					logger::info("the game's re-dress of {} adds no new set of their outfit {:08X}, its pieces are items of theirs", owner->GetName(), a_outfit->GetFormID());
				}
			}

			static inline REL::Relocation<decltype(thunk)> original;
		};

		// The call at a_offset of a_function when it's a call of a_to there, what was read on 1.7.104, 1.6.1170 and
		// 1.5.97. Else the log says what stands there and nothing is hooked
		std::optional<std::uintptr_t> CallAt(REL::RelocationID a_function, REL::VariantOffset a_offset, REL::RelocationID a_to, std::string_view a_what)
		{
			const auto place = REL::Relocation<std::uintptr_t>{ a_function }.address() + a_offset.offset();
			const auto to = REL::Relocation<std::uintptr_t>{ a_to }.address();
			const auto* code = reinterpret_cast<const std::uint8_t*>(place);
			if (code[0] == kCall && place + kCallSize + *reinterpret_cast<const std::int32_t*>(place + 1) == to) {
				return place;
			}
			logger::warn("the gate on the game's re-dress of followers leaves {} as the game has it, {}+{:X} holds {:02X} {:02X} {:02X} {:02X} {:02X} and no call of {} (game {})", a_what,
				a_function.id(), a_offset.offset(), code[0], code[1], code[2], code[3], code[4], a_to.id(), REL::Module::get().version().string());
			return std::nullopt;
		}

		void Gate()
		{
			auto& trampoline = SKSE::GetTrampoline();
			if (const auto place = CallAt(kRedress, kStripCall, kStrip, "the strip before it")) {
				Strip::original = trampoline.write_call<5>(*place, Strip::thunk);
			}
			if (const auto place = CallAt(kRedress, kBestWeapon, kEquipObject, "its best weapon")) {
				BestEquip<0>::original = trampoline.write_call<5>(*place, BestEquip<0>::thunk);
			}
			if (const auto place = CallAt(kRedress, kBestArmor, kEquipObject, "its best armor")) {
				BestEquip<1>::original = trampoline.write_call<5>(*place, BestEquip<1>::thunk);
			}
			const auto outfit = CallAt(kRedress, kOutfitCall, kAddWornOutfit, "the outfit");
			const auto piece = CallAt(kAddWornOutfit, kOutfitPiece, kEquipObject, "the outfit");
			if (outfit) {
				WornOutfit::original = trampoline.write_call<5>(*outfit, WornOutfit::thunk);
			}
			if (piece) {
				OutfitPiece::original = trampoline.write_call<5>(*piece, OutfitPiece::thunk);
			}
			const Detour::Place newSet{ kNewSet.id(), kNewSetStart, kNewSetStart.size(), kNewSetStart.size() };
			auto played = Detour::Take(newSet, reinterpret_cast<std::uintptr_t>(&NewSet::thunk));
			if (!played) {
				played = Detour::TakeJump(newSet.function, reinterpret_cast<std::uintptr_t>(&NewSet::thunk));
			}
			if (played) {
				NewSet::original = played;
			} else {
				logger::warn("the start of the game's InitOutfitItems holds neither its own bytes nor a plugin's jump (game {}), a follower's outfit may come back as a new set", REL::Module::get().version().string());
			}
		}
	}

	namespace
	{
		// A one handed weapon put in the right hand with the left one empty leaves it empty, the game and the combat AI
		// fill it with a shield of the bag otherwise, the outfit's one too. A shield the player puts on later goes as ever
		void LeftStaysEmpty(RE::Actor& a_actor, Kept& a_kept)
		{
			auto* changes = a_actor.GetInventoryChanges();
			if (!changes || !changes->entryList || a_actor.GetEquippedObject(true) ||
				std::ranges::any_of(a_kept.on, [](const On& a_on) { return (HandsOf(RE::TESForm::LookupByID(a_on.form), a_on.left) & kLeftHandBit) != 0; })) {
				return;
			}
			std::vector<RE::FormID> shields;
			for (const auto* entry : *changes->entryList) {
				const auto* armor = entry && entry->object ? entry->object->As<RE::TESObjectARMO>() : nullptr;
				if (!armor || !armor->IsShield()) {
					continue;
				}
				if (entry->IsWorn()) {
					return;
				}
				shields.push_back(armor->GetFormID());
			}
			for (const auto form : shields) {
				if (std::ranges::find(a_kept.off, form) == a_kept.off.end() && a_kept.off.size() < kMostPieces) {
					a_kept.off.push_back(form);
				}
			}
			if (!shields.empty()) {
				logger::info("the left hand of {} stays empty as the player left it, {} shields stay in the bag", a_actor.GetName(), shields.size());
			}
		}
	}

	void Chosen(RE::Actor& a_actor, RE::TESBoundObject& a_object, bool a_on, bool a_left)
	{
		if (a_actor.IsPlayerRef() || !Gear(&a_object)) {
			return;
		}
		const auto form = a_object.GetFormID();
		const std::scoped_lock lock{ keptLock };
		auto found = kept.find(a_actor.GetFormID());
		if (found == kept.end()) {
			if (kept.size() >= kMostActors) {
				logger::warn("the panel keeps the gear of {} followers already, not of {}", kMostActors, a_actor.GetName());
				return;
			}
			found = kept.emplace(a_actor.GetFormID(), Kept{}).first;
		}
		auto& one = found->second;
		const On chosen{ form, a_left };
		if (a_on) {
			std::erase(one.off, form);
			std::erase_if(one.on, [&](const On& a_other) { return a_other.form == form || SamePlace(a_other, chosen); });
			if (one.on.size() < kMostPieces) {
				one.on.push_back(chosen);
			}
			if (!a_left && a_object.Is(RE::FormType::Weapon) && !BothHands(&a_object)) {
				LeftStaysEmpty(a_actor, one);
			}
		} else {
			std::erase_if(one.on, [&](const On& a_other) { return a_other.form == form; });
			if (std::ranges::find(one.off, form) == one.off.end() && one.off.size() < kMostPieces) {
				one.off.push_back(form);
			}
		}
		// a new choice clears the fights of their pieces, and what changed by the trade itself is no change to undo
		one.fights.clear();
		++one.choices;
		one.owedSince.reset();
		any = true;
	}

	void Revealed(RE::Actor& a_actor, RE::FormID a_outfit)
	{
		const std::scoped_lock lock{ revealedLock };
		if (!revealed.contains(a_actor.GetFormID()) && revealed.size() >= kMostActors) {
			logger::warn("the outfits of {} followers are items of theirs already, the game may give {} a new set", kMostActors, a_actor.GetName());
			return;
		}
		auto& outfits = revealed[a_actor.GetFormID()];
		if (std::ranges::find(outfits, a_outfit) == outfits.end() && outfits.size() < kMostOutfits) {
			outfits.push_back(a_outfit);
		}
	}

	bool Knows(RE::FormID a_actor)
	{
		if (!any.load()) {
			return false;
		}
		const std::scoped_lock lock{ keptLock };
		return kept.contains(a_actor);
	}

	void Listen()
	{
		static Equips equips;
		static Loads loads;
		static Returns returns;
		RE::ScriptEventSourceHolder::GetSingleton()->AddEventSink<RE::TESEquipEvent>(&equips);
		RE::ScriptEventSourceHolder::GetSingleton()->AddEventSink<RE::TESObjectLoadedEvent>(&loads);
		RE::ScriptEventSourceHolder::GetSingleton()->AddEventSink<RE::TESContainerChangedEvent>(&returns);
		int hooked = HookScore(RE::VTABLE_CombatInventoryItemMelee[0], REL::RelocationID(43796, 45015), "melee weapons") +
		             HookScore(RE::VTABLE_CombatInventoryItemRanged[0], REL::RelocationID(43812, 45031), "bows and crossbows") +
		             HookScore(RE::VTABLE_CombatInventoryItemShield[0], REL::RelocationID(43826, 45045), "shields") +
		             HookScore(RE::VTABLE_CombatInventoryItemOneHandedBlock[0], REL::RelocationID(43835, 45054), "weapons to block with") +
		             HookScore(RE::VTABLE_CombatInventoryItemTorch[0], REL::RelocationID(43846, 45065), "torches");
		for (const auto& table : kMagicTables) {
			hooked += HookScore(table, REL::RelocationID(43863, 45082), "spells and staves");
		}
		logger::info("the combat AI keeps to the player's choices on followers for {} of {} kinds of entries", hooked, 5 + kMagicTables.size());
		Gate();
	}

	void Frame()
	{
		if (!Working()) {
			wasOff = true;
			return;
		}
		if (!any.load()) {
			wasOff = false;
			return;
		}
		if (ItemMenuOpen()) {
			return;
		}
		const auto now = Clock::now();
		// the keeping was switched on again, what the player chose while it was off goes back on, a round of no fight
		if (std::exchange(wasOff, false)) {
			const std::scoped_lock lock{ keptLock };
			for (auto& [actor, one] : kept) {
				one.owedSince = now;
				one.excused = true;
			}
		}
		std::vector<RE::FormID> due;
		{
			const std::scoped_lock lock{ keptLock };
			for (const auto& [actor, one] : kept) {
				if (one.owedSince && now - *one.owedSince >= kSettle) {
					due.push_back(actor);
				}
			}
		}
		for (const auto id : due) {
			auto* actor = RE::TESForm::LookupByID<RE::Actor>(id);
			if (!actor || !actor->Is3DLoaded() || actor->IsDead() || actor->IsDisabled() || Subject::ReadOnlyActor(id)) {
				continue;
			}
			// The gear goes back on a copy with the lock let go. The game sends its equip and load events from inside
			// the equip call, and the sinks of this file take the lock: held here, a second lock of it on this thread
			// threw and took the game down, and a sink on another thread waiting for it held the game's event lock
			Kept copy;
			{
				const std::scoped_lock lock{ keptLock };
				auto found = kept.find(id);
				if (found == kept.end()) {
					continue;
				}
				found->second.owedSince.reset();
				copy = found->second;
			}
			Restore(*actor, copy, now);
			const std::scoped_lock lock{ keptLock };
			auto found = kept.find(id);
			// what is no longer carried, the pieces let go and the fights counted go back unless the player chose anew
			// meanwhile, the new choice stands then
			if (found == kept.end() || found->second.choices != copy.choices) {
				continue;
			}
			found->second.on = std::move(copy.on);
			found->second.off = std::move(copy.off);
			found->second.fights = std::move(copy.fights);
			found->second.repaired = copy.repaired;
		}
	}

	void Save(SKSE::SerializationInterface* a_save)
	{
		const std::scoped_lock lock{ keptLock, revealedLock };
		// An actor made in the game and deleted since stays out, a new one made later may get its form id. One of a
		// plugin stays whether found or not, its cell may only be unloaded now
		const auto gone = [](const auto& a_one) {
			if ((a_one.first >> 24) != 0xFF) {
				return false;
			}
			const auto* actor = RE::TESForm::LookupByID<RE::Actor>(a_one.first);
			return !actor || actor->IsDeleted();
		};
		std::erase_if(kept, gone);
		std::erase_if(revealed, gone);
		if (kept.empty() && revealed.empty()) {
			return;
		}
		if (!a_save->OpenRecord(kRecord, kVersion)) {
			logger::error("the gear the player chose for followers could not be saved");
			return;
		}
		a_save->WriteRecordData(static_cast<std::uint32_t>(kept.size()));
		for (const auto& [actor, one] : kept) {
			a_save->WriteRecordData(actor);
			a_save->WriteRecordData(static_cast<std::uint32_t>(one.on.size()));
			for (const auto& on : one.on) {
				a_save->WriteRecordData(on.form);
				a_save->WriteRecordData(static_cast<std::uint8_t>(on.left ? 1 : 0));
			}
			a_save->WriteRecordData(static_cast<std::uint32_t>(one.off.size()));
			for (const auto form : one.off) {
				a_save->WriteRecordData(form);
			}
		}
		a_save->WriteRecordData(static_cast<std::uint32_t>(revealed.size()));
		for (const auto& [actor, outfits] : revealed) {
			a_save->WriteRecordData(actor);
			a_save->WriteRecordData(static_cast<std::uint32_t>(outfits.size()));
			for (const auto outfit : outfits) {
				a_save->WriteRecordData(outfit);
			}
		}
	}

	void Read(SKSE::SerializationInterface* a_save, std::uint32_t a_version)
	{
		std::uint32_t actors = 0;
		if (a_version < 1 || a_version > kVersion || !a_save->ReadRecordData(actors)) {
			return;
		}
		std::unordered_map<RE::FormID, Kept> read;
		for (std::uint32_t at = 0; at < actors && at < kMostActors; ++at) {
			RE::FormID saved = 0;
			std::uint32_t count = 0;
			Kept one;
			if (!a_save->ReadRecordData(saved) || !a_save->ReadRecordData(count)) {
				break;
			}
			// every piece is read so the next one starts in its place, a mod taken out lets its pieces go
			for (std::uint32_t piece = 0; piece < count; ++piece) {
				RE::FormID form = 0;
				std::uint8_t left = 0;
				RE::FormID now = 0;
				// a record cut short ends the reading, the count of a broken one could be anything
				if (!a_save->ReadRecordData(form) || !a_save->ReadRecordData(left)) {
					break;
				}
				if (a_save->ResolveFormID(form, now) && one.on.size() < kMostPieces) {
					one.on.push_back({ now, left != 0 });
				}
			}
			if (!a_save->ReadRecordData(count)) {
				break;
			}
			for (std::uint32_t piece = 0; piece < count; ++piece) {
				RE::FormID form = 0;
				RE::FormID now = 0;
				if (!a_save->ReadRecordData(form)) {
					break;
				}
				if (a_save->ResolveFormID(form, now) && one.off.size() < kMostPieces) {
					one.off.push_back(now);
				}
			}
			RE::FormID actor = 0;
			if (a_save->ResolveFormID(saved, actor) && (!one.on.empty() || !one.off.empty())) {
				// the game dresses everyone anew as the save loads, the choices go back on once it settles
				one.owedSince = Clock::now();
				read.emplace(actor, std::move(one));
			}
		}
		// a save of an older build has no outfits, no copy lost its mark then
		std::unordered_map<RE::FormID, std::vector<RE::FormID>> bare;
		if (a_version >= 2 && a_save->ReadRecordData(actors)) {
			for (std::uint32_t at = 0; at < actors && at < kMostActors; ++at) {
				RE::FormID saved = 0;
				std::uint32_t count = 0;
				if (!a_save->ReadRecordData(saved) || !a_save->ReadRecordData(count)) {
					break;
				}
				std::vector<RE::FormID> outfits;
				for (std::uint32_t outfit = 0; outfit < count; ++outfit) {
					RE::FormID form = 0;
					RE::FormID now = 0;
					if (!a_save->ReadRecordData(form)) {
						break;
					}
					if (a_save->ResolveFormID(form, now) && outfits.size() < kMostOutfits) {
						outfits.push_back(now);
					}
				}
				RE::FormID actor = 0;
				if (a_save->ResolveFormID(saved, actor) && !outfits.empty()) {
					bare.emplace(actor, std::move(outfits));
				}
			}
		}
		const std::scoped_lock lock{ keptLock, revealedLock };
		kept = std::move(read);
		revealed = std::move(bare);
		any = !kept.empty();
		logger::info("the gear the player chose is kept for {} followers and {} carry their outfit as plain items, read from the save", kept.size(), revealed.size());
	}

	void Forget()
	{
		const std::scoped_lock lock{ keptLock, revealedLock };
		kept.clear();
		refusalsTold.clear();
		revealed.clear();
		setsTold.clear();
		any = false;
	}
}
