#pragma once

// The doll stands the same way whatever the player does at the moment the menu opens: riding, sitting,
// sneaking or mid swing. Bone turns of a calm standing idle, taken once from the game, go onto the copy
namespace Pose
{
	// puts the copy into the shipped standing pose of its sex, false if the copy has none of its bones (beast form). A
	// torch in the left hand holds the arm up the way the game's torch idle does, a calm arm hung it down by the hip
	bool Stand(RE::NiAVObject& a_copy, bool a_female, bool a_torch = false);

	bool HoldsTorch(RE::Actor& a_actor);

	// the props an animation hangs in the hands go out of sight on a doll that stands calm
	void DropProps(RE::NiAVObject& a_copy);

	// at a crafting station the bones the standing pose leaves alone take the skeleton file's rest, the body works there
	void Settle(RE::NiAVObject& a_copy, RE::Actor& a_actor, bool a_female, bool a_torch);

	// at a station the bones keep the places the first copy of that person gave them, Unsteady forgets them
	void Steady(RE::NiAVObject& a_copy, RE::Actor& a_actor);
	void Unsteady();

	// tells which bones of the doll moved since the doll was copied the time before
	void TellDrift(RE::NiAVObject& a_copy);

	// Whether the copy keeps the pose of the moment, the player's choice "As in the world". Not in first person: the
	// player never sees their body there, and mods of first person animations play a stance made for the camera on
	// it, a crouch with the knees bent
	bool KeepsWorldPose();

	// Head and spine of a copy taken as it is get the turn of the race skeleton file, so a player who looked
	// aside or ran with the camera turned doesn't stand twisted. Arms and legs keep their pose
	void LookAhead(RE::NiAVObject& a_copy, RE::Actor& a_player);

	// writes the bones of the live player into SKSE/InventoryReforged-pose-<sex>.txt, the source of StandingPose.h,
	// into -<sex>-torch.txt while a torch is in the left hand
	void Dump(RE::NiAVObject& a_body, bool a_female, bool a_torch);

	// The doll can come out squashed in the belly with the body fine in the world. The log gets the length and size of
	// the spine, arm and leg bones in the live body, in the doll and in the race skeleton at rest, with the camera,
	// once for each new reading
	void Tell(RE::NiAVObject& a_body, RE::NiAVObject& a_copy, RE::Actor& a_shown);
}
