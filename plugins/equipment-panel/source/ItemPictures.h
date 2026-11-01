#pragma once

// Pictures of items for the rows of a list. Each item is drawn once with the light of the menu, the same anywhere in
// the world, finished so it reads on any ground and kept as a file, so a row costs a small image and no model after that
namespace ItemPictures
{
	// the address Flash loads the picture by, empty while there is none
	std::string Url(RE::FormID a_item);
	// the items in sight in the order of the rows, these are the ones to draw next
	void Want(const std::vector<RE::FormID>& a_items);
	// the whole list, other categories too. These get ready behind the scenes, so scrolling or a new category finds them
	void Ahead(const std::vector<RE::FormID>& a_items);
	// Loads a few files and reads the model of the next item wanted, the read can't be split so it stays one a call. An
	// item out of sight is drawn only while the player does nothing, a_idle
	void Grow(bool a_idle);
	bool Waiting();
	// While a menu draws, its render target bound. Draws the item that is ready in the middle of the screen, what it
	// covers goes back right after
	void Frame();
	void Clear();

	// From the thread that loads a save, when it is done. What the player and the followers carry gets its pictures while
	// the loading screen stays up. Comes back when they are done or the screen stopped drawing
	void DrawOnLoad();
	// each frame of the loading screen, on its own thread. Draws, and shows how far it got
	void LoadingFrame(RE::IMenu& a_menu);
}
