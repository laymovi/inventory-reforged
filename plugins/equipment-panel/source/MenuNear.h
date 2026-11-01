#pragma once

// The menus' 3D camera keeps the world's near plane, 15 units, while everything a menu shows stands some 500 units off.
// The depth buffer then tells two layers a hair apart badly (a strap on a boot, gloves over an undersuit), and the one
// behind shows through in patches. While a menu draws its 3D the near plane comes up to just before the nearest model
// it shows, and goes back right after
namespace MenuNear
{
	// [Debug] iMenuNear: the game's own plane, the plane just before the nearest model, or a plane at that many units
	constexpr std::int32_t kGameNear = -1;
	constexpr std::int32_t kAuto = 0;

	class Closer
	{
	public:
		explicit Closer(std::int32_t a_setting);
		~Closer();

		Closer(const Closer&) = delete;
		Closer& operator=(const Closer&) = delete;

	private:
		RE::NiCamera* camera = nullptr;
		float kept = 0.0F;
	};
}
