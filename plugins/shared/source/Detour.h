#pragma once

// Takes over the start of a game function. The first bytes of the function give way to a jump to our code,
// and a small piece of code is made that plays the function on from behind them, so our code can still
// call the function as it was
namespace Detour
{
	struct Place
	{
		// the function by its number in the address library
		std::uint64_t function;
		// the bytes its start must hold: another game version or the patch of another plugin gives others
		std::span<const std::uint8_t> start;
		// how many of those bytes are whole instructions that work from any address, they are played first
		std::size_t moved;
		// how far from the start the function goes on after them
		std::size_t resume;
	};

	// The address that plays the function on, or 0 when the start holds other bytes and is left alone
	std::uintptr_t Take(const Place& a_place, std::uintptr_t a_ours);

	// For a start another plugin holds with a jump (jmp rel32 or jmp [rip], Microsoft Detours and SKSE's trampoline write
	// those): our code goes in front of it. The address the jump led to, 0 when the start is no such jump
	std::uintptr_t TakeJump(std::uint64_t a_function, std::uintptr_t a_ours);

	// Room in the trampoline one taken function needs
	std::size_t Room(const Place& a_place);
}
