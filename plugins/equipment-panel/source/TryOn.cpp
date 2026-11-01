#include "PCH.h"

#include "TryOn.h"

#include "Hidden.h"
#include "Subject.h"

#include <Windows.h>

namespace TryOn
{
	namespace
	{
		// The game builds an actor's worn 3D in function 24725 of 1.7.104: it visits the worn entries of the actor's
		// inventory (16096, InventoryChanges::VisitWornItems) and reads which slots they take (24724 asks 16044,
		// GetWornMask) to switch off what they cover. Apparel Preview and Fitting Room hook these two calls too, a call
		// that leads to another plugin is taken over and still ends in the game's. 1.5.97 builds
		// the same way, only its second visit is a function of its own, 24231, that 24221 calls where
		// 1.7.104 has it inline. The mask is asked at +0x7C of 24220 there
		constexpr REL::RelocationID kBuildWorn{ 24231, 24725 };
		constexpr REL::VariantOffset kVisitCall{ 0x81, 0x1EF, 0 };
		constexpr REL::RelocationID kVisitWorn{ 15856, 16096 };
		// 24725 visits the worn entries twice (+0xFC and +0x1EF on 1.7.104), the second visit builds the 3D. 24231
		// visits them once
		std::size_t VisitNth()
		{
			return REL::Relocate<std::size_t>(1, 2);
		}
		constexpr REL::RelocationID kCoverBody{ 24220, 24724 };
		constexpr REL::VariantOffset kMaskCall{ 0x7C, 0x80, 0 };
		constexpr REL::RelocationID kWornMask{ 15806, 16044 };
		constexpr std::size_t kMaskNth = 1;
		constexpr std::uint8_t kCall = 0xE8;
		constexpr std::size_t kCallSize = 5;
		// how far into each function its call is looked for, the place moves between builds of the game
		constexpr std::size_t kLookAhead = 0x400;
		// the builds the places above were checked on, 1.7.104 and 1.5.97 with a disassembler and 1.6.1170 by
		// running it. Only there a call at the place that leads into another plugin counts as that plugin's hook
		constexpr std::array kChecked{ REL::Version{ 1, 7, 104, 0 }, REL::Version{ 1, 6, 1170, 0 }, REL::Version{ 1, 5, 97, 0 } };
		// how many bytes of code go into the log where a call is missing or leads into no loaded file
		constexpr std::size_t kShownBytes = 14;

		// what each actor has tried on, by the actor's form id. The hooks run for every body the game builds, they
		// look no further while nobody tries anything on
		std::mutex lock;
		std::map<RE::FormID, std::vector<RE::FormID>> tried;
		std::set<RE::FormID> rebuildOwed;
		std::atomic<bool> anyTried{ false };
		std::atomic<std::uint32_t> changes{ 0 };
		thread_local bool injecting = false;

		RE::FormID OwnerOf(const RE::InventoryChanges* a_changes)
		{
			return a_changes && a_changes->owner ? a_changes->owner->GetFormID() : 0;
		}

		std::vector<RE::TESObjectARMO*> ArmorOf(RE::FormID a_actor)
		{
			std::vector<RE::TESObjectARMO*> pieces;
			const std::scoped_lock hold{ lock };
			const auto found = tried.find(a_actor);
			if (found == tried.end()) {
				return pieces;
			}
			for (const auto form : found->second) {
				if (auto* armor = RE::TESForm::LookupByID<RE::TESObjectARMO>(form)) {
					pieces.push_back(armor);
				}
			}
			return pieces;
		}

		std::uint32_t MaskOf(RE::FormID a_actor)
		{
			std::uint32_t parts = 0;
			for (auto* armor : ArmorOf(a_actor)) {
				parts |= armor->GetSlotMask().underlying();
			}
			return parts;
		}

		void Counted()
		{
			const std::scoped_lock hold{ lock };
			anyTried = std::ranges::any_of(tried, [](const auto& a_pair) { return !a_pair.second.empty(); });
			++changes;
		}

		// the worn pieces first as the game has them, then the tried armor down the same visitor
		struct VisitWorn
		{
			static void thunk(RE::InventoryChanges* a_changes, RE::InventoryChanges::IItemChangeVisitor& a_visitor)
			{
				original(a_changes, a_visitor);
				if (!anyTried.load()) {
					return;
				}
				for (auto* armor : ArmorOf(OwnerOf(a_changes))) {
					RE::InventoryEntryData entry{ armor, 1 };
					injecting = true;
					a_visitor.Visit(&entry);
					injecting = false;
				}
			}

			static inline REL::Relocation<decltype(thunk)> original;
		};

		// the slots only worn armor a tried piece keeps off the body takes, none of the worn armor left on takes them
		std::uint32_t KeptOffMask(const RE::InventoryChanges& a_changes, std::uint32_t a_tried)
		{
			std::uint32_t off = 0;
			std::uint32_t on = 0;
			if (!a_changes.entryList) {
				return 0;
			}
			for (auto* entry : *a_changes.entryList) {
				const auto* armor = entry && entry->object ? entry->object->As<RE::TESObjectARMO>() : nullptr;
				const auto own = armor ? armor->GetSlotMask().underlying() : 0;
				if (armor && entry->IsWorn()) {
					((own & a_tried) != 0 ? off : on) |= own;
				}
			}
			return off & ~on;
		}

		// The body switches off what the worn slots cover. A worn piece a tried one keeps off covers nothing
		struct WornMask
		{
			static std::uint32_t thunk(RE::InventoryChanges* a_changes)
			{
				const auto real = original(a_changes);
				const auto tried = anyTried.load() && a_changes ? MaskOf(OwnerOf(a_changes)) : 0;
				return tried != 0 ? (real & ~KeptOffMask(*a_changes, tried)) | tried : real;
			}

			static inline REL::Relocation<decltype(thunk)> original;
		};

		bool IsCall(std::uintptr_t a_place)
		{
			return *reinterpret_cast<const std::uint8_t*>(a_place) == kCall;
		}

		std::uintptr_t TargetOf(std::uintptr_t a_call)
		{
			return a_call + kCallSize + *reinterpret_cast<const std::int32_t*>(a_call + 1);
		}

		// a page of PAGE_EXECUTE alone faults on a read
		bool Readable(std::uintptr_t a_place, std::size_t a_size)
		{
			constexpr DWORD kReads = PAGE_READONLY | PAGE_READWRITE | PAGE_WRITECOPY | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY;
			MEMORY_BASIC_INFORMATION memory{};
			if (!VirtualQuery(reinterpret_cast<const void*>(a_place), &memory, sizeof(memory)) || memory.State != MEM_COMMIT) {
				return false;
			}
			const auto end = reinterpret_cast<std::uintptr_t>(memory.BaseAddress) + memory.RegionSize;
			return (memory.Protect & kReads) != 0 && (memory.Protect & PAGE_GUARD) == 0 && a_place + a_size <= end;
		}

		// where a call ends up, past a jump of SKSE's trampoline (FF 25, then the address) when it goes through one
		std::uintptr_t Landing(std::uintptr_t a_place)
		{
			constexpr std::array<std::uint8_t, 6> kJump{ 0xFF, 0x25, 0x00, 0x00, 0x00, 0x00 };
			if (Readable(a_place, kJump.size() + sizeof(std::uintptr_t)) && std::memcmp(reinterpret_cast<const void*>(a_place), kJump.data(), kJump.size()) == 0) {
				return *reinterpret_cast<const std::uintptr_t*>(a_place + kJump.size());
			}
			return a_place;
		}

		HMODULE ModuleOf(std::uintptr_t a_place)
		{
			HMODULE module = nullptr;
			const auto flags = GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
			return GetModuleHandleExW(flags, reinterpret_cast<LPCWSTR>(a_place), &module) ? module : nullptr;
		}

		std::string FileOf(HMODULE a_module)
		{
			std::wstring path(32768, L'\0');
			path.resize(GetModuleFileNameW(a_module, path.data(), static_cast<DWORD>(path.size())));
			return path.empty() ? std::string("?") : SKSE::stl::utf16_to_utf8(std::filesystem::path(path).filename().wstring()).value_or("?");
		}

		std::string BytesAt(std::uintptr_t a_place, std::size_t a_count)
		{
			std::string bytes;
			for (std::size_t at = 0; at < a_count; ++at) {
				bytes += std::format("{}{:02X}", at ? " " : "", *reinterpret_cast<const std::uint8_t*>(a_place + at));
			}
			return bytes;
		}

		// A plugin's hook leads into its own file, straight or through SKSE's trampoline. Any other place a call
		// leads to outside the game is no hook this knows
		bool IntoPlugin(std::uintptr_t a_place)
		{
			const auto module = ModuleOf(Landing(a_place));
			return module && reinterpret_cast<std::uintptr_t>(module) != REL::Module::get().base();
		}

		// what stands at a_offset of function a_id, for the log when the call to a_to isn't found. A file name there
		// says whose hook took the place
		std::string Missed(std::uint64_t a_id, std::ptrdiff_t a_offset, std::uint64_t a_to)
		{
			const auto place = REL::Relocation<std::uintptr_t>{ REL::ID(a_id) }.address() + a_offset;
			const auto head = std::format("the worn pass call to {} wasn't found in {}", a_to, a_id);
			if (!IsCall(place)) {
				return std::format("{}, there's no call at +{:X}, the code there starts {}", head, a_offset, BytesAt(place, kShownBytes));
			}
			const auto landing = Landing(TargetOf(place));
			if (const auto module = ModuleOf(landing)) {
				return std::format("{}, the call at +{:X} leads into {}+{:X}", head, a_offset, FileOf(module), landing - reinterpret_cast<std::uintptr_t>(module));
			}
			if (Readable(landing, kShownBytes)) {
				return std::format("{}, the call at +{:X} leads to {:X} outside any loaded file, the code there starts {}", head, a_offset, landing, BytesAt(landing, kShownBytes));
			}
			return std::format("{}, the call at +{:X} leads to {:X}, a place that can't be read", head, a_offset, landing);
		}

		// The call in function a_id that leads to the game's function a_to. On any build it's taken at a_offset when
		// it leads straight there. On the checked builds a call at a_offset into another plugin is that plugin's hook
		// and tried pieces go after it. Other builds look for the a_nth call that leads there, the place moves between
		// builds and the order stays
		std::optional<std::uintptr_t> CallAt(std::uint64_t a_id, std::ptrdiff_t a_offset, std::uint64_t a_to, std::size_t a_nth)
		{
			const auto start = REL::Relocation<std::uintptr_t>{ REL::ID(a_id) }.address();
			const auto to = REL::Relocation<std::uintptr_t>{ REL::ID(a_to) }.address();
			const auto code = REL::Module::get().segment(REL::Segment::textx);
			const auto end = code.address() + code.size();
			const auto known = start + a_offset;
			if (IsCall(known) && TargetOf(known) == to) {
				return known;
			}
			if (std::ranges::find(kChecked, REL::Module::get().version()) != kChecked.end()) {
				if (IsCall(known) && IntoPlugin(TargetOf(known))) {
					logger::info("the call at {}+{:X} leads to another plugin first, tried pieces go after it", a_id, a_offset);
					return known;
				}
				return std::nullopt;
			}
			std::size_t seen = 0;
			for (std::size_t at = 0; at < kLookAhead && start + at + kCallSize <= end; ++at) {
				const auto place = start + at;
				if (IsCall(place) && TargetOf(place) == to && ++seen == a_nth) {
					logger::info("the call {} of {} to {} stands at +{:X} on this game", a_nth, a_id, a_to, at);
					return place;
				}
			}
			return std::nullopt;
		}

		bool installed = false;

		void Rebuild(RE::Actor& a_actor)
		{
			if (auto* process = a_actor.GetActorRuntimeData().currentProcess) {
				process->Set3DUpdateFlag(RE::RESET_3D_FLAGS::kModel);
			}
			a_actor.Update3DModel();
		}

		// A station leaves the world running, and the frame of the menu is drawn while the NPCs' own updates run on
		// other threads. A companion's body is built among the menus' work instead, the way a trade builds it, a
		// paused world never put a newly loaded piece on an NPC's body. One who sits, rides or lies keeps the build
		// for later: the station tries again next frame, after it the world does. Dropped, a piece tried on stayed
		// on their body in the world after the station closed
		void RebuildLater(RE::FormID a_id)
		{
			SKSE::GetTaskInterface()->AddUITask([a_id] {
				auto* companion = RE::TESForm::LookupByID<RE::Actor>(a_id);
				if (!companion) {
					return;
				}
				if (Subject::Rebuildable(*companion)) {
					IR_BRACKET("the body of {:08X} is built again for pieces tried on", a_id);
					Rebuild(*companion);
					Hidden::BodyBuilt(*companion);
				} else if (RE::UI::GetSingleton()->IsMenuOpen(RE::CraftingMenu::MENU_NAME)) {
					const std::scoped_lock hold{ lock };
					rebuildOwed.insert(a_id);
				} else {
					Hidden::OweFollowerBody(a_id);
				}
			});
		}

		// the player's body through the hidden slots' own rebuild, a companion's in the next frame of the menu
		void BuildAgain(RE::Actor& a_actor)
		{
			if (a_actor.IsPlayerRef()) {
				Hidden::BuildAgain();
				return;
			}
			const std::scoped_lock hold{ lock };
			rebuildOwed.insert(a_actor.GetFormID());
		}
	}

	void Install()
	{
		const auto game = REL::Module::get().version().string();
		const auto visit = CallAt(kBuildWorn.id(), kVisitCall.offset(), kVisitWorn.id(), VisitNth());
		const auto cover = CallAt(kCoverBody.id(), kMaskCall.offset(), kWornMask.id(), kMaskNth);
		if (!visit || !cover) {
			std::string missed;
			if (!visit) {
				missed = Missed(kBuildWorn.id(), kVisitCall.offset(), kVisitWorn.id());
			}
			if (!cover) {
				missed += (missed.empty() ? "" : ", and ") + Missed(kCoverBody.id(), kMaskCall.offset(), kWornMask.id());
			}
			logger::warn("trying pieces on in crafting menus stays off, {} (game {})", missed, game);
			return;
		}
		auto& trampoline = SKSE::GetTrampoline();
		VisitWorn::original = trampoline.write_call<5>(*visit, VisitWorn::thunk);
		WornMask::original = trampoline.write_call<5>(*cover, WornMask::thunk);
		installed = true;
		logger::info("pieces can be tried on in crafting menus");
	}

	bool Ready()
	{
		return installed;
	}

	bool Set(RE::Actor& a_actor, RE::FormID a_form, bool a_on)
	{
		if (!installed) {
			return false;
		}
		auto* form = RE::TESForm::LookupByID(a_form);
		auto* armor = form ? form->As<RE::TESObjectARMO>() : nullptr;
		const bool weapon = form && form->Is(RE::FormType::Weapon);
		if (!armor && !weapon) {
			return false;
		}
		const auto parts = armor ? armor->GetSlotMask().underlying() : 0;
		{
			const std::scoped_lock hold{ lock };
			auto& pieces = tried[a_actor.GetFormID()];
			std::erase(pieces, a_form);
			if (a_on) {
				std::erase_if(pieces, [&](RE::FormID a_other) {
					const auto* other = RE::TESForm::LookupByID(a_other);
					const auto* otherArmor = other ? other->As<RE::TESObjectARMO>() : nullptr;
					if (!other) {
						return true;
					}
					return weapon ? other->Is(RE::FormType::Weapon) : otherArmor && (otherArmor->GetSlotMask().underlying() & parts) != 0;
				});
				pieces.push_back(a_form);
			}
		}
		Counted();
		logger::info("{} {} for show on {}", form->GetName(), a_on ? "is tried on" : "comes off", a_actor.GetName());
		if (armor) {
			BuildAgain(a_actor);
		}
		return true;
	}

	std::vector<RE::FormID> Worn(const RE::Actor& a_actor)
	{
		const std::scoped_lock hold{ lock };
		const auto found = tried.find(a_actor.GetFormID());
		return found == tried.end() ? std::vector<RE::FormID>{} : found->second;
	}

	RE::TESObjectWEAP* Weapon(const RE::Actor& a_actor)
	{
		if (!anyTried.load()) {
			return nullptr;
		}
		for (const auto form : Worn(a_actor)) {
			if (auto* weapon = RE::TESForm::LookupByID<RE::TESObjectWEAP>(form)) {
				return weapon;
			}
		}
		return nullptr;
	}

	std::uint32_t Changes()
	{
		return changes.load();
	}

	void Forget()
	{
		const std::scoped_lock hold{ lock };
		tried.clear();
		rebuildOwed.clear();
		anyTried = false;
		++changes;
	}

	void Clear()
	{
		std::vector<RE::FormID> wearers;
		{
			const std::scoped_lock hold{ lock };
			for (const auto& [actor, pieces] : tried) {
				if (std::ranges::any_of(pieces, [](RE::FormID a_form) { return RE::TESForm::LookupByID<RE::TESObjectARMO>(a_form) != nullptr; })) {
					wearers.push_back(actor);
				}
			}
			tried.clear();
			// a piece taken off while they sat is still on their body
			for (const auto id : rebuildOwed) {
				if (std::ranges::find(wearers, id) == wearers.end()) {
					wearers.push_back(id);
				}
			}
			rebuildOwed.clear();
		}
		anyTried = false;
		++changes;
		if (wearers.empty()) {
			return;
		}
		logger::info("the pieces tried on come off");
		for (const auto id : wearers) {
			if (auto* actor = RE::TESForm::LookupByID<RE::Actor>(id)) {
				if (actor->IsPlayerRef()) {
					Hidden::BuildAgain();
				} else {
					// the menu is gone, the companion's body is built again by the world's task
					RebuildLater(id);
				}
			}
		}
	}

	void MenuFrame()
	{
		std::set<RE::FormID> owed;
		{
			const std::scoped_lock hold{ lock };
			owed.swap(rebuildOwed);
		}
		for (const auto id : owed) {
			RebuildLater(id);
		}
	}

	std::uint32_t Mask(const RE::Actor& a_actor)
	{
		return anyTried.load() ? MaskOf(a_actor.GetFormID()) : 0;
	}

	bool Covers(const RE::Actor& a_actor, const RE::TESBoundObject* a_object)
	{
		const auto* armor = a_object ? a_object->As<RE::TESObjectARMO>() : nullptr;
		return armor && !injecting && anyTried.load() && (armor->GetSlotMask().underlying() & MaskOf(a_actor.GetFormID())) != 0;
	}

	bool Injecting()
	{
		return injecting;
	}
}
