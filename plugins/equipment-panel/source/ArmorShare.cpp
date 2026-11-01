#include "PCH.h"

#include "ArmorShare.h"

#include <excpt.h>

namespace ArmorShare
{
	namespace
	{
		// The function (38558 of 1.7.104 and 1.6.1170, 37605 of 1.5.97) takes an actor and a share of health, reads the
		// actor's health and armor rating through its values at +0xB8 (+0xB0 on 1.5.97), times the rating by
		// fArmorScalingFactor / 100, asks the actor for the hidden share of its worn pieces (call [vtable + 0x738] at
		// +0x7A, +0x7C on 1.5.97), adds the two, stops at 0.99 and gives back the health over what's left. From that call
		// to the stop is where a mod puts its own sum: Blade and Blunt 4 branches away at the call itself and drops the
		// hidden share, Armor Rating Rescaled rewrites the add and the stop after it. Both do the same in the hit
		constexpr REL::RelocationID kFunction{ 37605, 38558 };
		constexpr std::array<std::uint8_t, 10> kStart{ 0x48, 0x89, 0x5C, 0x24, 0x08, 0x57, 0x48, 0x83, 0xEC, 0x50 };
		constexpr std::size_t kValuesAt = 0x30;
		constexpr std::array<std::uint8_t, 3> kValuesRead{ 0x48, 0x8B, 0x87 };
		constexpr REL::VariantOffset kHiddenCall{ 0x7C, 0x7A, 0 };
		constexpr std::array<std::uint8_t, 2> kCallThrough{ 0xFF, 0x90 };
		// the place of the hidden share in the actor's table on all three versions, for a call a mod branched away from
		constexpr std::uint32_t kHiddenSlot = 0x738;
		constexpr std::array<std::uint8_t, 4> kOwnSum{ 0xF3, 0x0F, 0x10, 0x0D };
		// the hit's own call for the hidden share and its sum (44014+0xF9, 42842+0x101 on 1.5.97), only told in the log. A
		// branch at the call leaves the sum after it as it was, unreached
		constexpr REL::RelocationID kHit{ 42842, 44014 };
		constexpr REL::VariantOffset kHitSum{ 0x101, 0xF9, 0 };
		constexpr std::array<std::uint8_t, 15> kOwnHitSum{ 0xFF, 0x90, 0x38, 0x07, 0x00, 0x00, 0xF3, 0x0F, 0x10, 0x4D, 0x77, 0xF3, 0x0F, 0x58, 0xC8 };

		constexpr std::size_t kActorRoom = 64;
		constexpr std::size_t kTableRoom = 512;

		struct Layout
		{
			std::uintptr_t function = 0;
			std::uint32_t values = 0;
			std::uint32_t hidden = 0;
		};

		thread_local float rating = 0.0F;
		thread_local float hidden = 0.0F;

		float Nothing(void*)
		{
			return 0.0F;
		}

		float Hidden(void*)
		{
			return hidden;
		}

		// health 1 leaves the function's answer as 1 over what's let through
		float Value(void*, RE::ActorValue a_value)
		{
			switch (a_value) {
			case RE::ActorValue::kDamageResist:
				return rating;
			case RE::ActorValue::kHealth:
				return 1.0F;
			default:
				return 0.0F;
			}
		}

		template <std::size_t N>
		bool Same(std::uintptr_t a_at, const std::array<std::uint8_t, N>& a_bytes)
		{
			return std::memcmp(reinterpret_cast<const void*>(a_at), a_bytes.data(), N) == 0;
		}

		std::string Bytes(std::uintptr_t a_at, std::size_t a_count)
		{
			std::string text;
			for (std::size_t i = 0; i < a_count; ++i) {
				text += std::format("{:02X} ", *reinterpret_cast<const std::uint8_t*>(a_at + i));
			}
			return text;
		}

		std::uint32_t Distance(std::uintptr_t a_at)
		{
			std::uint32_t distance = 0;
			std::memcpy(&distance, reinterpret_cast<const void*>(a_at), sizeof(distance));
			return distance;
		}

		Layout Read()
		{
			const auto function = kFunction.address();
			const auto call = function + kHiddenCall.offset();
			if (!Same(function, kStart) || !Same(function + kValuesAt, kValuesRead)) {
				logger::info("armor share: the game's function at {:X} isn't the one this knows ({}| {}), the numbers count by the game settings", kFunction.offset(),
					Bytes(function, kStart.size()), Bytes(function + kValuesAt, kValuesRead.size()));
				return {};
			}
			const bool ownCall = Same(call, kCallThrough);
			Layout layout{ function, Distance(function + kValuesAt + kValuesRead.size()), ownCall ? Distance(call + kCallThrough.size()) : kHiddenSlot };
			if (layout.values % 8 != 0 || layout.values / 8 >= kActorRoom || layout.hidden % 8 != 0 || layout.hidden / 8 >= kTableRoom) {
				logger::info("armor share: the function reads its values at +{:X} and the hidden share at +{:X}, out of what this builds, the numbers count by the game settings", layout.values, layout.hidden);
				return {};
			}
			const bool ownSum = ownCall && Same(call + 6, kOwnSum);
			const bool ownHit = Same(kHit.address() + kHitSum.offset(), kOwnHitSum);
			logger::info("armor share: the function's sum is {}, the hit's {}, the numbers ask the function", ownSum ? "the game's" : "rewritten by a plugin", ownHit ? "the game's" : "rewritten by a plugin");
			if (ownSum && !ownHit) {
				logger::info("armor share: a plugin counts armor in hits its own way and left the function as it was, the numbers may differ from the hits");
			}
			return layout;
		}

		// a plugin that went into the function some other way than its sum may read more of the stand-in, that costs
		// no crash, the panel counts by the settings from then on
		bool Ask(std::uintptr_t a_function, void* a_actor, float& a_health) noexcept
		{
			using Function = float (*)(void*, float);
			__try {
				a_health = reinterpret_cast<Function>(a_function)(a_actor, 1.0F);
				return true;
			} __except (EXCEPTION_EXECUTE_HANDLER) {
				return false;
			}
		}
	}

	// The function is given a stand-in for the actor: its two tables answer the rating, a health of 1 and the hidden share,
	// everything else nothing
	std::optional<float> Of(float a_rating, float a_hidden)
	{
		static const Layout layout = Read();
		static std::atomic_bool failed{ false };
		if (!layout.function || failed.load()) {
			return std::nullopt;
		}
		static const auto tables = [] {
			auto made = std::make_unique<std::array<std::array<void*, kTableRoom>, 2>>();
			(*made)[0].fill(reinterpret_cast<void*>(&Nothing));
			(*made)[1].fill(reinterpret_cast<void*>(&Nothing));
			(*made)[0][layout.hidden / 8] = reinterpret_cast<void*>(&Hidden);
			(*made)[1][1] = reinterpret_cast<void*>(&Value);
			return made;
		}();
		alignas(16) std::array<void*, kActorRoom> actor{};
		actor[0] = (*tables)[0].data();
		actor[layout.values / 8] = (*tables)[1].data();
		rating = a_rating;
		hidden = a_hidden;
		float health = 0.0F;
		if (!Ask(layout.function, actor.data(), health)) {
			failed = true;
			logger::info("armor share: the function broke on the stand-in for rating {} and hidden share {}, the numbers count by the game settings from now on", a_rating, a_hidden);
			return std::nullopt;
		}
		if (std::isnan(health) || health == 0.0F) {
			return std::nullopt;
		}
		static std::atomic_bool told{ false };
		if (!told.exchange(true)) {
			logger::info("armor share: rating {} with a hidden share of {} stops {} of a hit before the cap", a_rating, a_hidden, 1.0F - 1.0F / health);
		}
		return 1.0F - 1.0F / health;
	}
}
