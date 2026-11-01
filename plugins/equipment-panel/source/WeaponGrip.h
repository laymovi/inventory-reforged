#pragma once

namespace WeaponGrip
{
	// The game asks the weapon's equip slot how many hands it takes. Grip mods like Combat Gameplay Overhaul change
	// that slot and leave the swing alone, so a greatsword can go one handed. The swing is only for a weapon with no slot
	inline bool BothHands(const RE::TESForm* a_form)
	{
		constexpr RE::FormID kBothHandsSlot = 0x13F45;
		const auto* weapon = a_form ? a_form->As<RE::TESObjectWEAP>() : nullptr;
		if (!weapon) {
			return false;
		}
		if (const auto* slot = weapon->GetEquipSlot()) {
			return slot->GetFormID() == kBothHandsSlot;
		}
		return !weapon->IsOneHandedSword() && !weapon->IsOneHandedDagger() && !weapon->IsOneHandedAxe() && !weapon->IsOneHandedMace() &&
		       !weapon->IsStaff() && !weapon->IsHandToHandMelee();
	}
}
