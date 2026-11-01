#pragma once

// What share of a hit armor stops, asked of the game's own sum. The game keeps that sum in one small function too
// (38558, SE 37605: an actor's health over the share it lets through), and mods that change how armor turns into
// protection rewrite it there and in the hit (Blade and Blunt, Armor Rating Rescaled), so the panel counts their way
namespace ArmorShare
{
	// the share before the cap fMaxArmorRating, for an armor rating and the hidden share of the worn pieces of light or
	// heavy armor (fArmorBaseFactor each). Empty when the game's function isn't the one this knows, the panel counts by
	// the game settings then
	std::optional<float> Of(float a_rating, float a_hidden);
}
