#pragma once

struct ID3D11ShaderResourceView;

// Community Shaders shades hair against the depth of the screen (Hair Specular, self shadow), from a slot of its own it
// fills while the world draws. Over an item menu that slot still holds the world behind the menu, and a wall behind the
// player darkened the doll's hair. While a menu draws its 3D the slot holds a depth all at the far plane, nothing stands
// in front of the doll, and the slot gets its own depth back right after. A slot holding anything but a depth is left be
namespace MenuDepth
{
	class Far
	{
	public:
		explicit Far(bool a_wanted);
		~Far();

		Far(const Far&) = delete;
		Far& operator=(const Far&) = delete;

	private:
		bool put = false;
		ID3D11ShaderResourceView* kept = nullptr;
	};
}
