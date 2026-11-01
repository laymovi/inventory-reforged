#include "PCH.h"

#include "ChangedBy.h"

#include <intrin.h>
#include <unordered_set>

#include "Detour.h"
#include "Keep.h"
#include "SafeRead.h"

#ifndef WIN32_LEAN_AND_MEAN
#	define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#	define NOMINMAX
#endif
#include <Windows.h>

// windows.h renames GetObject to GetObjectW, a script variable has a GetObject of its own
#undef GetObject

namespace ChangedBy
{
	namespace
	{
		using Clock = std::chrono::steady_clock;

		constexpr std::uint32_t kVersion = 1;
		constexpr std::size_t kMostActors = 64;
		constexpr std::size_t kMostPieces = 16;
		// A script's equip is queued by the native (54661+0x153 on 1.7.104) and goes on in the actor's update (39814+0xD0),
		// measured 6 to 22 ms later. Its mod is named on that equip for this long
		constexpr auto kQueuedFor = 10s;
		constexpr std::size_t kMostQueued = 64;
		// the return addresses right over the game's equip a plugin's DLL is looked for in, deeper ones are the game's
		// loops and the hooks other plugins put on them
		constexpr std::size_t kCallers = 4;
		// room for this plugin's own frames under them
		constexpr std::size_t kOwnFrames = 4;
		constexpr std::size_t kMostScriptFrames = 64;
		constexpr std::array kGameFiles{ "Skyrim.esm"sv, "Update.esm"sv, "Dawnguard.esm"sv, "HearthFires.esm"sv, "Dragonborn.esm"sv };

		// ActorEquipManager::EquipObject and UnequipObject, their starts read on 1.7.104, 1.6.1170 (the same bytes) and
		// 1.5.97. EquipObject begins with test rdx, rdx and a jump to its end when there's no actor, the thunk makes that
		// check itself and the game's code goes on past it. UnequipObject begins with mov r11, rsp (mov rax, rsp on 1.5.97)
		// and two pushes, which run as well from anywhere
		constexpr REL::RelocationID kEquip{ 37938, 38894 };
		constexpr REL::RelocationID kUnequip{ 37945, 38901 };
		constexpr std::array<std::uint8_t, 9> kEquipStartAE{ 0x48, 0x85, 0xD2, 0x0F, 0x84, 0xC3, 0x01, 0x00, 0x00 };
		constexpr std::array<std::uint8_t, 9> kEquipStartSE{ 0x48, 0x85, 0xD2, 0x0F, 0x84, 0x2F, 0x01, 0x00, 0x00 };
		constexpr std::array<std::uint8_t, 6> kUnequipStartAE{ 0x4C, 0x8B, 0xDC, 0x57, 0x41, 0x54 };
		constexpr std::array<std::uint8_t, 6> kUnequipStartSE{ 0x48, 0x8B, 0xC4, 0x57, 0x41, 0x56 };

		Detour::Place EquipPlace()
		{
			const auto& start = REL::Module::IsAE() ? kEquipStartAE : kEquipStartSE;
			return { kEquip.id(), start, 0, start.size() };
		}

		Detour::Place UnequipPlace()
		{
			const auto& start = REL::Module::IsAE() ? kUnequipStartAE : kUnequipStartSE;
			return { kUnequip.id(), start, start.size(), start.size() };
		}

		bool hooked = false;

		// who changes a follower's gear on this thread now: the mod of a script's call or a plugin, or the panel itself
		struct Doing
		{
			RE::FormID actor = 0;
			const std::string* by = nullptr;
			bool ours = false;
		};
		thread_local Doing doing;

		class Scope
		{
		public:
			explicit Scope(const std::optional<Doing>& a_doing) :
				before(doing),
				set(a_doing.has_value())
			{
				if (set) {
					doing = *a_doing;
				}
			}

			~Scope()
			{
				if (set) {
					doing = before;
				}
			}

			Scope(const Scope&) = delete;
			Scope& operator=(const Scope&) = delete;

		private:
			Doing before;
			bool set;
		};

		std::mutex namesLock;
		// every name met, kept for the whole game so a pointer to one stays good on any thread
		std::unordered_set<std::string> names;

		const std::string* Named(std::string_view a_name)
		{
			const std::scoped_lock lock{ namesLock };
			return &*names.emplace(a_name).first;
		}

		bool GameFile(std::string_view a_name)
		{
			return std::ranges::any_of(kGameFiles, [&](std::string_view a_game) { return a_name.size() == a_game.size() && _strnicmp(a_name.data(), a_game.data(), a_game.size()) == 0; });
		}

		struct Piece
		{
			RE::FormID form;
			const std::string* by;
			bool on;
		};

		// a script's equip the game put in the actor's queue, its mod goes along to the equip that comes of it
		struct Queued
		{
			RE::FormID actor;
			RE::FormID form;
			bool on;
			const std::string* by;
			Clock::time_point at;
		};

		std::mutex recordsLock;
		// per follower, the latest change last
		std::unordered_map<RE::FormID, std::vector<Piece>> records;
		std::vector<Queued> queued;
		bool fullTold = false;

		bool Gear(const RE::TESForm* a_form)
		{
			return a_form && (a_form->Is(RE::FormType::Armor) || a_form->Is(RE::FormType::Weapon) || a_form->Is(RE::FormType::Ammo) || a_form->Is(RE::FormType::Light));
		}

		// a teammate is a flag of the actor, anyone else costs a lookup in Keep
		bool Watched(const RE::Actor& a_actor)
		{
			return !a_actor.IsPlayerRef() && (a_actor.IsPlayerTeammate() || Keep::Knows(a_actor.GetFormID()));
		}

		bool Worn(RE::Actor& a_actor, const RE::TESBoundObject& a_object)
		{
			auto* changes = a_actor.GetInventoryChanges();
			if (!changes || !changes->entryList) {
				return false;
			}
			for (auto* entry : *changes->entryList) {
				if (entry && entry->object == &a_object) {
					return entry->IsWorn();
				}
			}
			return false;
		}

		void Record(const RE::Actor& a_actor, const RE::TESBoundObject& a_object, bool a_on, const std::string& a_by)
		{
			const auto id = a_actor.GetFormID();
			const auto form = a_object.GetFormID();
			bool full = false;
			bool fresh = false;
			{
				const std::scoped_lock lock{ recordsLock };
				if (!records.contains(id) && records.size() >= kMostActors) {
					full = !std::exchange(fullTold, true);
				} else {
					auto& pieces = records[id];
					const auto same = std::ranges::find(pieces, form, &Piece::form);
					fresh = same == pieces.end() || same->by != &a_by || same->on != a_on;
					if (same != pieces.end()) {
						pieces.erase(same);
					}
					pieces.push_back({ form, &a_by, a_on });
					if (pieces.size() > kMostPieces) {
						pieces.erase(pieces.begin());
					}
				}
			}
			if (full) {
				logger::warn("the panel tells which mod changed the gear of {} followers already, not of {}", kMostActors, a_actor.GetName());
			} else if (fresh) {
				logger::info("{} {} {} by {}", a_object.GetName(), a_on ? "was put on" : "was taken off", a_actor.GetName(), a_by);
			}
		}

		void Queue(RE::FormID a_actor, RE::FormID a_form, bool a_on, const std::string& a_by)
		{
			const auto now = Clock::now();
			const std::scoped_lock lock{ recordsLock };
			std::erase_if(queued, [&](const Queued& a_one) { return now - a_one.at >= kQueuedFor || (a_one.actor == a_actor && a_one.form == a_form); });
			if (queued.size() < kMostQueued) {
				queued.push_back({ a_actor, a_form, a_on, &a_by, now });
			}
		}

		const std::string* QueuedBy(RE::FormID a_actor, RE::FormID a_form, bool a_on)
		{
			const auto now = Clock::now();
			const std::scoped_lock lock{ recordsLock };
			const auto found = std::ranges::find_if(queued, [&](const Queued& a_one) {
				return a_one.actor == a_actor && a_one.form == a_form && a_one.on == a_on && now - a_one.at < kQueuedFor;
			});
			return found != queued.end() ? found->by : nullptr;
		}

		// A piece that comes off is noted only while it's worn, outfit scripts take off every slot whatever is there
		void Note(RE::Actor& a_actor, const RE::TESBoundObject* a_object, bool a_on, bool a_queue, const std::string& a_by)
		{
			if (!Gear(a_object) || (!a_on && !Worn(a_actor, *a_object))) {
				return;
			}
			Record(a_actor, *a_object, a_on, a_by);
			if (a_queue) {
				Queue(a_actor.GetFormID(), a_object->GetFormID(), a_on, a_by);
			}
		}

		// a place of code: the game's, SKSE's and a trampoline's say nothing, this plugin's is ours, another DLL is a mod
		struct Place
		{
			bool ours = false;
			const std::string* plugin = nullptr;
		};

		struct Module
		{
			const std::string* file = nullptr;
			bool skse = false;
		};

		std::mutex modulesLock;
		std::unordered_map<HMODULE, Module> modules;

		HMODULE ModuleOf(const void* a_address)
		{
			HMODULE module = nullptr;
			const auto flags = GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
			return GetModuleHandleExW(flags, static_cast<LPCWSTR>(a_address), &module) ? module : nullptr;
		}

		HMODULE GameModule()
		{
			static const HMODULE game = GetModuleHandleW(nullptr);
			return game;
		}

		HMODULE OwnModule()
		{
			static const HMODULE own = ModuleOf(reinterpret_cast<const void*>(&Named));
			return own;
		}

		std::string Utf8(std::wstring_view a_text)
		{
			const auto size = WideCharToMultiByte(CP_UTF8, 0, a_text.data(), static_cast<int>(a_text.size()), nullptr, 0, nullptr, nullptr);
			std::string text(static_cast<std::size_t>(std::max(size, 0)), '\0');
			WideCharToMultiByte(CP_UTF8, 0, a_text.data(), static_cast<int>(a_text.size()), text.data(), size, nullptr, nullptr);
			return text;
		}

		Module Described(HMODULE a_module)
		{
			const std::scoped_lock lock{ modulesLock };
			auto found = modules.find(a_module);
			if (found == modules.end()) {
				std::wstring path(MAX_PATH, L'\0');
				path.resize(GetModuleFileNameW(a_module, path.data(), static_cast<DWORD>(path.size())));
				const auto file = Utf8(std::filesystem::path(path).filename().native());
				const bool skse = file.size() >= 7 && _strnicmp(file.c_str(), "skse64_", 7) == 0;
				found = modules.emplace(a_module, Module{ file.empty() ? nullptr : Named(file), skse }).first;
			}
			return found->second;
		}

		Place PlaceOf(const void* a_address)
		{
			const auto module = ModuleOf(a_address);
			if (!module || module == GameModule()) {
				return {};
			}
			if (module == OwnModule()) {
				return { true };
			}
			const auto described = Described(module);
			return { false, described.skse ? nullptr : described.file };
		}

		// The start of the function a place of code lies in, by the unwind data of its module. A function the compiler
		// split in parts chains the data of a part to the one of its start. 0 for a place with none
		std::uintptr_t FunctionOf(std::uintptr_t a_address)
		{
			constexpr std::uint8_t kChained = 0x4;
			DWORD64 base = 0;
			const auto* entry = RtlLookupFunctionEntry(a_address, &base, nullptr);
			for (std::size_t hop = 0; entry && hop < 4; ++hop) {
				const auto* info = reinterpret_cast<const std::uint8_t*>(base + entry->UnwindData);
				if (((info[0] >> 3) & kChained) == 0) {
					break;
				}
				const std::size_t codes = (info[2] + 1u) & ~1u;
				entry = reinterpret_cast<const RUNTIME_FUNCTION*>(info + 4 + codes * 2);
			}
			return entry ? static_cast<std::uintptr_t>(base + entry->BeginAddress) : 0;
		}

		// A plugin that hooks the start of the game's equip after this one puts its own function in front of ours.
		// Follower Equip Control 2.1.0 did so with Microsoft Detours as the data loaded, on 1.5.97 every call came here
		// from its module, the game's dressing and the panel's equips alike. Such a function passes the call on, its
		// frames right over ours are skipped and the caller over them is looked at, so its module's own code calling the
		// game still names it. What this can't tell: a hook that changes the item inside itself (FEC's own pick of a
		// weapon over the AI's) passes for whoever called it, the game most often
		struct Passing
		{
			HMODULE module = nullptr;
			// 0 when the module has no unwind data for it, one frame of the module is skipped then
			std::uintptr_t function = 0;
		};
		constexpr std::size_t kMostPassing = 4;
		// a hook's frames over ours: its function and the helpers it passes the call through
		constexpr std::size_t kPassingFrames = 3;
		constexpr std::size_t kMostHops = 8;

		struct Front
		{
			std::uintptr_t start = 0;
			// the first bytes at the start when they were last followed
			std::uint64_t seen = 0;
			std::array<Passing, kMostPassing> passing{};
			std::size_t count = 0;
			const char* what = "";
		};
		std::mutex frontLock;
		Front equipFront;
		Front unequipFront;

		// where the jumps at a function's start lead: through jmp rel32 and jmp [rip] to the first code that is no jump
		std::uintptr_t Landing(std::uintptr_t a_start)
		{
			auto at = a_start;
			for (std::size_t hop = 0; hop < kMostHops; ++hop) {
				std::array<std::uint8_t, 6> code{};
				std::int32_t by = 0;
				if (!SafeRead::Copy(code.data(), at, code.size())) {
					break;
				}
				if (code[0] == 0xE9) {
					std::memcpy(&by, code.data() + 1, sizeof(by));
					at = static_cast<std::uintptr_t>(static_cast<std::intptr_t>(at) + 5 + by);
				} else if (code[0] == 0xFF && code[1] == 0x25) {
					std::memcpy(&by, code.data() + 2, sizeof(by));
					std::uintptr_t to = 0;
					if (!SafeRead::Copy(&to, static_cast<std::uintptr_t>(static_cast<std::intptr_t>(at) + 6 + by), sizeof(to))) {
						break;
					}
					at = to;
				} else {
					break;
				}
			}
			return at;
		}

		// the hook at the start now, kept beside the ones met before, a newer hook leaves the older one in its chain
		void Learn(Front& a_front)
		{
			const auto landing = Landing(a_front.start);
			const auto module = ModuleOf(reinterpret_cast<const void*>(landing));
			if (!module || module == GameModule() || module == OwnModule()) {
				return;
			}
			const Passing hook{ module, FunctionOf(landing) };
			const auto end = a_front.passing.begin() + a_front.count;
			if (a_front.count >= kMostPassing ||
				std::find_if(a_front.passing.begin(), end, [&](const Passing& a_one) { return a_one.module == hook.module && a_one.function == hook.function; }) != end) {
				return;
			}
			a_front.passing[a_front.count++] = hook;
			const auto described = Described(module);
			logger::info("{} hooks the start of the game's {} in front of this plugin, the calls it passes on are told by who made them", described.file ? *described.file : "a DLL"s,
				a_front.what);
		}

		// The hooks in front of ours, followed again when the bytes at the start changed: a plugin may hook late
		Front Ahead(Front& a_front)
		{
			std::uint64_t now = 0;
			std::memcpy(&now, reinterpret_cast<const void*>(a_front.start), sizeof(now));
			const std::scoped_lock lock{ frontLock };
			if (now != a_front.seen) {
				a_front.seen = now;
				Learn(a_front);
			}
			return a_front;
		}

		// past the frames of one hook in front of ours: up to the one in its function, through helpers of its module
		std::size_t PastHook(std::span<void* const> a_stack, std::size_t a_at, const Front& a_front)
		{
			for (std::size_t i = 0; i < a_front.count; ++i) {
				const auto& hook = a_front.passing[i];
				for (auto at = a_at; at < a_stack.size() && at < a_at + kPassingFrames && ModuleOf(a_stack[at]) == hook.module; ++at) {
					if (hook.function == 0 || FunctionOf(reinterpret_cast<std::uintptr_t>(a_stack[at])) == hook.function) {
						return at + 1;
					}
				}
			}
			return a_at;
		}

		// The DLL whose code called the game's equip, the first of the return addresses over it that lies in one, past
		// the hooks in front of ours. a_from is the thunk's own return address, the call into the game's function
		__declspec(noinline) Place CallerOf(void* a_from, Front& a_front)
		{
			std::array<void*, kOwnFrames + kMostPassing * kPassingFrames + kCallers> frames{};
			const auto found = RtlCaptureStackBackTrace(0, static_cast<DWORD>(frames.size()), frames.data(), nullptr);
			std::span<void* const> stack{ frames.data(), found };
			auto from = std::ranges::find(stack, a_from);
			if (from == stack.end()) {
				frames[0] = a_from;
				stack = { frames.data(), 1 };
				from = stack.begin();
			}
			const auto front = Ahead(a_front);
			auto at = static_cast<std::size_t>(from - stack.begin());
			for (std::size_t round = 0; round < front.count; ++round) {
				const auto past = PastHook(stack, at, front);
				if (past == at) {
					break;
				}
				at = past;
			}
			for (std::size_t looked = 0; at < stack.size() && looked < kCallers; ++at, ++looked) {
				if (const auto place = PlaceOf(stack[at]); place.ours || place.plugin) {
					return place;
				}
			}
			return {};
		}

		// Who changes a follower's piece by this call of the game's equip: the scope this thread is in (a script's
		// native, a mod's call that pushes this piece off, the panel), the DLL that called, or the script whose queued
		// equip this is. What comes back is the scope for the call, the mod to note goes in a_by
		std::optional<Doing> Who(RE::Actor& a_actor, const RE::TESBoundObject* a_object, bool a_on, bool a_queue, void* a_from, const std::string*& a_by)
		{
			if (!Watched(a_actor)) {
				return std::nullopt;
			}
			const auto id = a_actor.GetFormID();
			if (doing.actor == id) {
				a_by = doing.by;
				return std::nullopt;
			}
			const auto caller = CallerOf(a_from, a_on ? equipFront : unequipFront);
			if (caller.ours) {
				return Doing{ id, nullptr, true };
			}
			a_by = caller.plugin ? caller.plugin : (a_queue || !a_object ? nullptr : QueuedBy(id, a_object->GetFormID(), a_on));
			return a_by ? std::optional<Doing>{ Doing{ id, a_by, false } } : std::nullopt;
		}

		struct Equip
		{
			static void thunk(RE::ActorEquipManager* a_manager, RE::Actor* a_actor, RE::TESBoundObject* a_object, RE::ExtraDataList* a_list, std::uint32_t a_count,
				const RE::BGSEquipSlot* a_slot, bool a_queue, bool a_force, bool a_sounds, bool a_now)
			{
				// the game's own first check, the way in jumps over it
				if (!a_actor) {
					return;
				}
				const std::string* by = nullptr;
				const Scope scope{ Who(*a_actor, a_object, true, a_queue, _ReturnAddress(), by) };
				if (by) {
					Note(*a_actor, a_object, true, a_queue, *by);
				}
				original(a_manager, a_actor, a_object, a_list, a_count, a_slot, a_queue, a_force, a_sounds, a_now);
			}

			static inline REL::Relocation<decltype(thunk)> original;
		};

		struct Unequip
		{
			static bool thunk(RE::ActorEquipManager* a_manager, RE::Actor* a_actor, RE::TESBoundObject* a_object, RE::ExtraDataList* a_list, std::uint32_t a_count,
				const RE::BGSEquipSlot* a_slot, bool a_queue, bool a_force, bool a_sounds, bool a_now, const RE::BGSEquipSlot* a_replaced)
			{
				const std::string* by = nullptr;
				const Scope scope{ a_actor ? Who(*a_actor, a_object, false, a_queue, _ReturnAddress(), by) : std::nullopt };
				if (by) {
					Note(*a_actor, a_object, false, a_queue, *by);
				}
				return original(a_manager, a_actor, a_object, a_list, a_count, a_slot, a_queue, a_force, a_sounds, a_now, a_replaced);
			}

			static inline REL::Relocation<decltype(thunk)> original;
		};

		// the form whose plugin a script's object stands for, of a mod or of the game's own masters
		struct Bound
		{
			const std::string* plugin = nullptr;
			bool game = false;
		};

		// The plugin of the form a script's object is bound to: a quest or a reference, the quest of an alias, the magic
		// effect of an active effect. A reference made in the game has no plugin, its base has. A handle of a form
		// carries its form id in the low half
		Bound BoundTo(const RE::BSScript::Variable& a_self)
		{
			if (!a_self.IsObject()) {
				return {};
			}
			const auto object = a_self.GetObject();
			if (!object) {
				return {};
			}
			const RE::TESForm* form = nullptr;
			if (const auto* effect = static_cast<const RE::ActiveEffect*>(object->Resolve(RE::ActiveEffect::VMTYPEID))) {
				form = effect->GetBaseObject() ? static_cast<const RE::TESForm*>(effect->GetBaseObject()) : effect->spell;
			} else if (const auto* alias = static_cast<const RE::BGSBaseAlias*>(object->Resolve(RE::BGSRefAlias::VMTYPEID))) {
				form = alias->owningQuest;
			} else if (const auto* place = static_cast<const RE::BGSBaseAlias*>(object->Resolve(RE::BGSLocAlias::VMTYPEID))) {
				form = place->owningQuest;
			} else {
				form = RE::TESForm::LookupByID(static_cast<RE::FormID>(object->GetHandle() & 0xFFFFFFFF));
			}
			const auto* file = form ? form->GetFile(0) : nullptr;
			if (!file) {
				const auto* reference = form ? form->As<RE::TESObjectREFR>() : nullptr;
				const auto* base = reference ? reference->GetBaseObject() : nullptr;
				file = base ? base->GetFile(0) : nullptr;
			}
			if (!file) {
				return {};
			}
			const auto name = file->GetFilename();
			return GameFile(name) ? Bound{ nullptr, true } : Bound{ Named(name) };
		}

		// Whose script calls a native: the plugin of the first object up the stack that stands on a mod's form. A stack
		// of the game's own scripts names no one, one of global functions alone names the calling script by its file
		const std::string* ScriptCaller(const RE::BSScript::StackFrame& a_native)
		{
			bool game = false;
			std::size_t depth = 0;
			for (const auto* frame = a_native.previousFrame; frame && depth < kMostScriptFrames; frame = frame->previousFrame, ++depth) {
				const auto bound = BoundTo(frame->self);
				if (bound.plugin) {
					return bound.plugin;
				}
				game = game || bound.game;
			}
			const auto* caller = a_native.previousFrame;
			if (game || !caller || !caller->owningObjectType) {
				return nullptr;
			}
			return Named(std::format("{}.pex", caller->owningObjectType->GetName()));
		}

		RE::Actor* ActorOf(const RE::BSScript::Variable& a_self)
		{
			if (!a_self.IsObject()) {
				return nullptr;
			}
			const auto object = a_self.GetObject();
			return object ? RE::TESForm::LookupByID<RE::Actor>(static_cast<RE::FormID>(object->GetHandle() & 0xFFFFFFFF)) : nullptr;
		}

		// Natives of Actor that change gear, the game's and SKSE's
		constexpr std::array kNatives{ "EquipItem", "UnequipItem", "UnequipAll", "UnequipItemSlot", "SetOutfit", "EquipItemEx", "EquipItemById", "UnequipItemEx" };

		using Dispatch = bool (*)(const RE::BSScript::NF_util::NativeFunctionBase*, RE::BSScript::Variable&, RE::BSScript::Internal::VirtualMachine&, RE::VMStackID,
			RE::BSScript::Variable&, const RE::BSScript::StackFrame&);

		// A native's MarshallAndDispatch, slot 0x16 of its table, takes the values off the script's frame and runs the
		// native. The game's NativeFunctionBase::Call reaches it through the table (call [rax+0xB0] at 104651+0x106 and
		// +0x1FF on 1.7.104 and 1.6.1170, at 97923+0x112 and +0x1F3 on 1.5.97), SKSE's natives the same way, EquipItemEx
		// comes from 104651+0x205. Each native wrapped gets a table of its own, a copy from the pointer to its RTTI right
		// before the table up to that slot, which points here
		constexpr std::size_t kDispatchSlot = 0x16;
		constexpr std::size_t kCopied = kDispatchSlot + 2;
		constexpr std::size_t kMostWrapped = 32;

		struct Wrapped
		{
			std::array<std::uintptr_t, kCopied> table{};
			Dispatch original = nullptr;
		};
		std::mutex wrapLock;
		std::array<Wrapped, kMostWrapped> wrapped;
		std::atomic<std::size_t> wrappedCount{ 0 };

		const std::uintptr_t* TableOf(const Wrapped& a_one)
		{
			return a_one.table.data() + 1;
		}

		const Wrapped* WrappedWith(const std::uintptr_t* a_table)
		{
			const auto count = wrappedCount.load(std::memory_order_acquire);
			for (std::size_t i = 0; i < count; ++i) {
				if (TableOf(wrapped[i]) == a_table) {
					return &wrapped[i];
				}
			}
			return nullptr;
		}

		bool Dispatched(const RE::BSScript::NF_util::NativeFunctionBase* a_function, RE::BSScript::Variable& a_self, RE::BSScript::Internal::VirtualMachine& a_machine,
			RE::VMStackID a_stack, RE::BSScript::Variable& a_result, const RE::BSScript::StackFrame& a_frame)
		{
			// only the tables made here lead to this function
			const auto* one = WrappedWith(*reinterpret_cast<const std::uintptr_t* const*>(a_function));
			auto* actor = ActorOf(a_self);
			const auto* by = actor && Watched(*actor) ? ScriptCaller(a_frame) : nullptr;
			const Scope scope{ by ? std::optional<Doing>{ Doing{ actor->GetFormID(), by, false } } : std::nullopt };
			return one->original(a_function, a_self, a_machine, a_stack, a_result, a_frame);
		}

		bool Wrap(RE::BSScript::IFunction& a_function)
		{
			auto*& table = *reinterpret_cast<const std::uintptr_t**>(&a_function);
			const auto at = wrappedCount.load();
			if (WrappedWith(table) || at >= kMostWrapped) {
				return false;
			}
			auto& one = wrapped[at];
			std::copy_n(table - 1, kCopied, one.table.begin());
			one.original = reinterpret_cast<Dispatch>(one.table[kDispatchSlot + 1]);
			one.table[kDispatchSlot + 1] = reinterpret_cast<std::uintptr_t>(&Dispatched);
			wrappedCount.store(at + 1, std::memory_order_release);
			table = TableOf(one);
			return true;
		}

		// a native of a type by its name, in the type's functions once the script is linked, in the list of natives bound
		// to it before
		RE::BSScript::IFunction* NativeOf(RE::BSScript::ObjectTypeInfo& a_type, const char* a_name)
		{
			const auto named = [&](const RE::BSScript::IFunction* a_function) {
				return a_function && a_function->GetIsNative() && _stricmp(a_function->GetName().c_str(), a_name) == 0;
			};
			if (!a_type.IsLinked()) {
				for (auto* unlinked = a_type.GetUnlinkedFunctionIter(); unlinked; unlinked = unlinked->next) {
					if (named(unlinked->func.get())) {
						return unlinked->func.get();
					}
				}
				return nullptr;
			}
			auto* members = a_type.GetMemberFuncIter();
			for (std::uint32_t i = 0; i < a_type.GetNumMemberFuncs(); ++i) {
				if (named(members[i].func.get())) {
					return members[i].func.get();
				}
			}
			return nullptr;
		}
	}

	namespace
	{
		// A plugin that loaded earlier holds the start already (FSMP takes UnequipObject): this one goes in front of its
		// jump, the call then passes through it to the game as it would. It stands behind ours, so no frames to skip
		std::uintptr_t TakeStart(const Detour::Place& a_place, std::uintptr_t a_ours, std::string_view a_what)
		{
			if (const auto played = Detour::Take(a_place, a_ours)) {
				return played;
			}
			const auto led = Detour::TakeJump(a_place.function, a_ours);
			if (led) {
				const auto module = ModuleOf(reinterpret_cast<const void*>(Landing(led)));
				const auto* name = module ? Described(module).file : nullptr;
				logger::info("{} holds the start of the game's {} already, this plugin goes in front of it", name ? *name : "a plugin", a_what);
			}
			return led;
		}
	}

	std::size_t Room()
	{
		return Detour::Room(EquipPlace()) + Detour::Room(UnequipPlace());
	}

	void Install()
	{
		const auto equips = TakeStart(EquipPlace(), reinterpret_cast<std::uintptr_t>(&Equip::thunk), "EquipObject");
		const auto unequips = TakeStart(UnequipPlace(), reinterpret_cast<std::uintptr_t>(&Unequip::thunk), "UnequipObject");
		if (equips) {
			Equip::original = equips;
		}
		if (unequips) {
			Unequip::original = unequips;
		}
		// the starts as they are with our own hook in place, a change of them later is a plugin's hook in front of ours
		for (auto* front : { &equipFront, &unequipFront }) {
			front->what = front == &equipFront ? "EquipObject" : "UnequipObject";
			front->start = REL::Relocation<std::uintptr_t>{ front == &equipFront ? kEquip : kUnequip }.address();
			std::memcpy(&front->seen, reinterpret_cast<const void*>(front->start), sizeof(front->seen));
		}
		hooked = equips || unequips;
		if (!equips || !unequips) {
			logger::warn("the start of the game's {} holds neither its own bytes nor a plugin's jump (game {}), the card names no mod that {} a follower's gear",
				!equips ? "EquipObject" : "UnequipObject", REL::Module::get().version().string(), !equips ? "puts on" : "takes off");
		}
	}

	void Listen()
	{
		auto* machine = RE::BSScript::Internal::VirtualMachine::GetSingleton();
		if (!hooked || !machine) {
			return;
		}
		const RE::BSFixedString actorType{ "Actor" };
		std::string missing;
		std::size_t found = 0;
		std::size_t fresh = 0;
		const std::scoped_lock lock{ wrapLock };
		{
			const RE::BSSpinLockGuard guard{ machine->typeInfoLock };
			const auto type = machine->objectTypeMap.find(actorType);
			for (const auto* name : kNatives) {
				auto* function = type != machine->objectTypeMap.end() && type->second ? NativeOf(*type->second.get(), name) : nullptr;
				if (!function) {
					missing += std::format("{}{}", missing.empty() ? ", not found: " : ", ", name);
					continue;
				}
				++found;
				fresh += Wrap(*function) ? 1 : 0;
			}
		}
		static bool told = false;
		if (!std::exchange(told, true)) {
			logger::info("a script that changes a follower's gear is named by its mod through {} of {} natives{}", found, kNatives.size(), missing);
		} else if (fresh > 0) {
			logger::info("{} natives that change gear were bound anew by another plugin, they name the mod of a script again", fresh);
		}
	}

	std::optional<Change> Last(RE::FormID a_actor, RE::FormID a_form)
	{
		const std::scoped_lock lock{ recordsLock };
		const auto found = records.find(a_actor);
		if (found == records.end()) {
			return std::nullopt;
		}
		const auto piece = std::ranges::find(found->second, a_form, &Piece::form);
		return piece != found->second.end() ? std::optional<Change>{ Change{ *piece->by, piece->on } } : std::nullopt;
	}

	void Cleared(RE::FormID a_actor, RE::FormID a_form)
	{
		const std::scoped_lock lock{ recordsLock };
		std::erase_if(queued, [&](const Queued& a_one) { return a_one.actor == a_actor && a_one.form == a_form; });
		const auto found = records.find(a_actor);
		if (found == records.end()) {
			return;
		}
		std::erase_if(found->second, [&](const Piece& a_piece) { return a_piece.form == a_form; });
		if (found->second.empty()) {
			records.erase(found);
		}
	}

	Ours::Ours(RE::FormID a_actor) :
		actor(doing.actor),
		by(doing.by),
		ours(doing.ours)
	{
		doing = { a_actor, nullptr, true };
	}

	Ours::~Ours()
	{
		doing = { actor, by, ours };
	}

	void Save(SKSE::SerializationInterface* a_save)
	{
		const std::scoped_lock lock{ recordsLock };
		// an actor made in the game and deleted since stays out, a new one made later may get its form id
		std::erase_if(records, [](const auto& a_one) {
			if ((a_one.first >> 24) != 0xFF) {
				return false;
			}
			const auto* actor = RE::TESForm::LookupByID<RE::Actor>(a_one.first);
			return !actor || actor->IsDeleted();
		});
		if (records.empty()) {
			return;
		}
		if (!a_save->OpenRecord(kRecord, kVersion)) {
			logger::error("which mods changed the gear of followers could not be saved");
			return;
		}
		a_save->WriteRecordData(static_cast<std::uint32_t>(records.size()));
		for (const auto& [actor, pieces] : records) {
			a_save->WriteRecordData(actor);
			a_save->WriteRecordData(static_cast<std::uint32_t>(pieces.size()));
			for (const auto& piece : pieces) {
				const auto length = static_cast<std::uint16_t>(std::min<std::size_t>(piece.by->size(), UINT16_MAX));
				a_save->WriteRecordData(piece.form);
				a_save->WriteRecordData(static_cast<std::uint8_t>(piece.on ? 1 : 0));
				a_save->WriteRecordData(length);
				a_save->WriteRecordData(piece.by->data(), length);
			}
		}
	}

	void Read(SKSE::SerializationInterface* a_save, std::uint32_t a_version)
	{
		std::uint32_t actors = 0;
		if (a_version != kVersion || !a_save->ReadRecordData(actors)) {
			return;
		}
		std::unordered_map<RE::FormID, std::vector<Piece>> read;
		bool whole = true;
		for (std::uint32_t at = 0; at < actors && whole; ++at) {
			RE::FormID saved = 0;
			std::uint32_t count = 0;
			if (!a_save->ReadRecordData(saved) || !a_save->ReadRecordData(count)) {
				break;
			}
			std::vector<Piece> pieces;
			// every piece is read so the next one starts in its place, a record cut short ends the reading
			for (std::uint32_t one = 0; one < count && whole; ++one) {
				RE::FormID form = 0;
				std::uint8_t on = 0;
				std::uint16_t length = 0;
				std::string by;
				whole = a_save->ReadRecordData(form) && a_save->ReadRecordData(on) && a_save->ReadRecordData(length);
				by.resize(whole ? length : 0);
				whole = whole && (length == 0 || a_save->ReadRecordData(by.data(), length) == length);
				RE::FormID now = 0;
				if (whole && !by.empty() && a_save->ResolveFormID(form, now) && pieces.size() < kMostPieces) {
					pieces.push_back({ now, Named(by), on != 0 });
				}
			}
			RE::FormID actor = 0;
			if (a_save->ResolveFormID(saved, actor) && !pieces.empty() && read.size() < kMostActors) {
				read.emplace(actor, std::move(pieces));
			}
		}
		const std::scoped_lock lock{ recordsLock };
		records = std::move(read);
		queued.clear();
		logger::info("which mod last changed a piece is known for {} followers, read from the save", records.size());
	}

	void Forget()
	{
		const std::scoped_lock lock{ recordsLock };
		records.clear();
		queued.clear();
		fullTold = false;
	}
}
