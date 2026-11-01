#pragma once

// The 3D scene menus draw item previews in, and where things in it land on screen. Places on screen are
// shares: 0..1 from the left and from the top, sizes are shares of the screen height
namespace Scene
{
	struct Axes
	{
		RE::NiPoint3 look;
		RE::NiPoint3 up;
		RE::NiPoint3 right;
	};

	// a box on screen, shares of the width across and of the height down
	struct Box
	{
		float left = 0.0F;
		float top = 0.0F;
		float right = 0.0F;
		float bottom = 0.0F;

		[[nodiscard]] bool Meets(const Box& a_other) const
		{
			return left < a_other.right && a_other.left < right && top < a_other.bottom && a_other.top < bottom;
		}
	};

	// how much room a model takes along the camera axes, in world units
	struct Extent
	{
		RE::NiPoint3 middle;
		float wide = 0.0F;
		float high = 0.0F;
		bool found = false;
	};

	// kUnder is drawn before the picture of the menu, the rest over it the way the game draws its 3D
	enum class Layer
	{
		kPanel,
		kUnder,
		kInspect
	};

	Axes Camera();
	RE::NiPoint3 Eye();
	RE::NiPoint3 Point(float a_fromLeft, float a_fromTop);
	// where a point of the scene lands on screen, shares from the left and from the top
	std::pair<float, float> Spot(const RE::NiPoint3& a_point);
	float Length(float a_shareOfHeight);
	float Aspect();
	// a box around a middle, its size in shares of the screen height
	Box Around(float a_centerX, float a_centerY, float a_wide, float a_high);

	void Turn(RE::NiAVObject& a_model, const RE::NiPoint3& a_right, const RE::NiPoint3& a_forward, const RE::NiPoint3& a_up);

	// the turn that sends a model's right, forward and up along these directions
	RE::NiMatrix3 Columns(const RE::NiPoint3& a_right, const RE::NiPoint3& a_forward, const RE::NiPoint3& a_up);

	RE::NiMatrix3 About(const RE::NiPoint3& a_axis, float a_radians);

	void Visit(RE::NiAVObject& a_model, const std::function<void(RE::NiAVObject&)>& a_visit);

	// A model with collision stands where its physics body is, which for a copy is the middle of the
	// scene. Models shown in a menu need no physics, so it's taken off
	void DropCollision(RE::NiAVObject& a_model);

	// The room the shapes that are drawn take, skinned ones measured from their bones. The model
	// has to be updated first
	Extent Measure(RE::NiAVObject& a_model);
	// for the log: how big a model was measured and the spheres of bones that reach farthest out of its middle
	std::string TellMeasure(RE::NiAVObject& a_model);

	// The points that show the outline of a drawn model, from its place, in the world: the vertices of shapes that
	// keep a copy of them, the edges of the spheres of the rest along the camera. A sword is a sphere as wide as it is
	// long, its vertices tell how thin it is and which way it lies. The model has to be updated first
	std::vector<RE::NiPoint3> Outline(RE::NiAVObject& a_model);

	void Add(RE::NiAVObject& a_model, const Box& a_box, Layer a_layer = Layer::kPanel);
	// in the scene but out of every picture, only DrawAlone draws it
	void AddHidden(RE::NiAVObject& a_model);
	// this model and nothing else, into what is bound now. With a_shown false it stays out too, the pass only binds its target
	void DrawAlone(RE::NiAVObject& a_model, bool a_shown = true);
	void Remove(RE::NiAVObject& a_model);

	// takes the panel models out of the picture or brings them back, what's added while hidden stays hidden
	void Hide(bool a_hidden);

	// A question of the panel over the menu (sell all junk?) lies over the model of the item, the whole 3D of the menu
	// is drawn before its picture while it's up. The models stay in sight
	void AllUnder(bool a_under);

	// Another mod may lay a screen of its own over the menu and fade the menu's movie out under it, Fitting Room's
	// editor does over the inventory. The panel's 3D isn't part of the movie and stood over that screen, the doll in
	// front of the character it shows and the slot models floating without their slots. Read every frame, the menu's
	// own script may not run while it's faded. The inspected item goes too
	void Fade();

	// panel models that meet the box go out of the picture until the cover is lifted, so a window of the
	// menu can lie over the spot. 3D is drawn over the menu, a model would stand over the window. The doll
	// is drawn under the menu and stays
	void Cover(const Box& a_box);
	void Uncover();

	// The models of kUnder are drawn alone with the game's own call, before the menu draws its picture, and
	// left out of the game's pass after it. False when there is nothing to draw under
	bool DrawUnder();
	// they come back for the next frame
	void DrawnUnder();

	// The lights of a menu are its own but the shaders read the ambient of the world, so in a cave everything in the
	// menu is black on its unlit side. While this lives they read an even ambient of this level, 0 leaves the world's
	class EvenAmbient
	{
	public:
		explicit EvenAmbient(float a_level);
		~EvenAmbient();
		EvenAmbient(const EvenAmbient&) = delete;
		EvenAmbient& operator=(const EvenAmbient&) = delete;

	private:
		std::optional<RE::NiTransform> kept;
	};

	// the game's temporal anti-aliasing of the menu's 3D left on or off while it lives, as it was after
	class TemporalBlend
	{
	public:
		explicit TemporalBlend(bool a_kept);
		~TemporalBlend();
		TemporalBlend(const TemporalBlend&) = delete;
		TemporalBlend& operator=(const TemporalBlend&) = delete;

	private:
		RE::ImageSpaceManager::UNK_BSImagespaceShaderISTemporalAA* temporal = nullptr;
		bool blended = false;
	};

	// The game's pass draws models only when the inventory's 3D names the light scheme the screen runs. Outside an item
	// menu it names none and the pass skips them, while this lives it names the screen's
	class ScreenLights
	{
	public:
		ScreenLights();
		~ScreenLights();
		ScreenLights(const ScreenLights&) = delete;
		ScreenLights& operator=(const ScreenLights&) = delete;

	private:
		RE::INTERFACE_LIGHT_SCHEME kept = RE::INTERFACE_LIGHT_SCHEME::kJournal;
	};

	// The game keeps the model of the selected item up where the item window stood last, also when the window
	// is gone (a drag, a dropped piece still selected). It goes out of sight with the window. KeepPreview runs
	// every frame of the inventory, a model loaded meanwhile follows
	void ShowPreview(bool a_shown);
	void KeepPreview();

	// whether the game still holds this model as a preview of the selected item. One it let go of is never
	// brought back into sight
	bool HeldPreview(const RE::NiAVObject& a_model);

	// whether this held preview is the model of the item the open menu has selected now. The game keeps the
	// models of the last few items too, out of sight, and only that one may come back
	bool SelectedPreview(const RE::NiAVObject& a_model);
}
