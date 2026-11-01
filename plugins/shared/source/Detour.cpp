#include "PCH.h"

#include "Detour.h"

namespace
{
#pragma pack(push, 1)
	// reaches any address, it lives in the trampoline next to the game's code
	struct FarJump
	{
		std::array<std::uint8_t, 6> jump{ 0xFF, 0x25, 0x00, 0x00, 0x00, 0x00 };
		std::uint64_t to = 0;
	};

	// fits into the start of a function and reaches the trampoline
	struct NearJump
	{
		std::uint8_t jump = 0xE9;
		std::int32_t by = 0;
	};
#pragma pack(pop)

	std::uint8_t* Written(const void* a_bytes, std::size_t a_count, const FarJump& a_then)
	{
		auto* code = static_cast<std::uint8_t*>(SKSE::GetTrampoline().allocate(a_count + sizeof(FarJump)));
		std::memcpy(code, a_bytes, a_count);
		std::memcpy(code + a_count, &a_then, sizeof(FarJump));
		return code;
	}
}

namespace Detour
{
	std::size_t Room(const Place& a_place)
	{
		return a_place.moved + 2 * sizeof(FarJump);
	}

	std::uintptr_t TakeJump(std::uint64_t a_function, std::uintptr_t a_ours)
	{
		const auto function = REL::Relocation<std::uintptr_t>{ REL::ID(a_function) }.address();
		const auto* code = reinterpret_cast<const std::uint8_t*>(function);
		std::uintptr_t led = 0;
		if (code[0] == 0xE9) {
			led = function + sizeof(NearJump) + *reinterpret_cast<const std::int32_t*>(code + 1);
		} else if (code[0] == 0xFF && code[1] == 0x25) {
			led = *reinterpret_cast<const std::uintptr_t*>(function + 6 + *reinterpret_cast<const std::int32_t*>(code + 2));
		}
		if (!led) {
			return 0;
		}
		const auto* gate = Written(code, 0, FarJump{ .to = a_ours });
		const auto distance = reinterpret_cast<std::intptr_t>(gate) - static_cast<std::intptr_t>(function + sizeof(NearJump));
		const NearJump in{ .by = static_cast<std::int32_t>(distance) };
		REL::safe_write(function, &in, sizeof(in));
		return led;
	}

	std::uintptr_t Take(const Place& a_place, std::uintptr_t a_ours)
	{
		const auto function = REL::Relocation<std::uintptr_t>{ REL::ID(a_place.function) }.address();
		const auto* start = reinterpret_cast<const void*>(function);
		if (std::memcmp(start, a_place.start.data(), a_place.start.size()) != 0) {
			return 0;
		}
		const auto* played = Written(start, a_place.moved, FarJump{ .to = function + a_place.resume });
		const auto* gate = Written(start, 0, FarJump{ .to = a_ours });
		const auto distance = reinterpret_cast<std::intptr_t>(gate) - static_cast<std::intptr_t>(function + sizeof(NearJump));
		const NearJump in{ .by = static_cast<std::int32_t>(distance) };
		REL::safe_write(function, &in, sizeof(in));
		return reinterpret_cast<std::uintptr_t>(played);
	}
}
