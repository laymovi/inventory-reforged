#include "PCH.h"

#include "Scene.h"

#include "Profile.h"

namespace Scene
{
	namespace
	{
		const RE::NiCamera& Lens()
		{
			return *RE::UI3DSceneManager::GetSingleton()->camera;
		}

		const RE::NiFrustum& Frustum()
		{
			return Lens().GetRuntimeData2().viewFrustum;
		}

		RE::NiPoint3 Column(const RE::NiMatrix3& a_turn, std::size_t a_index)
		{
			return { a_turn.entry[0][a_index], a_turn.entry[1][a_index], a_turn.entry[2][a_index] };
		}

		void SetColumn(RE::NiMatrix3& a_turn, std::size_t a_index, const RE::NiPoint3& a_axis)
		{
			a_turn.entry[0][a_index] = a_axis.x;
			a_turn.entry[1][a_index] = a_axis.y;
			a_turn.entry[2][a_index] = a_axis.z;
		}

		// Everything is placed as far from the camera as the game places item previews. The place is told when an item menu
		// begins its 3D, what's asked on the loading screen before that must not stick, the doll would stand far from its
		// lights for the whole game
		float Depth()
		{
			static std::optional<float> kept;
			if (kept) {
				return *kept;
			}
			const auto* manager = RE::Inventory3DManager::GetSingleton();
			const float depth = (manager->itemPos - Lens().world.translate).Dot(Camera().look);
			if (manager->currentLightScheme != RE::INTERFACE_LIGHT_SCHEME::kJournal && manager->currentLightScheme != RE::INTERFACE_LIGHT_SCHEME::kLoading) {
				kept = depth;
			}
			return depth;
		}

		struct Kept
		{
			RE::NiPointer<RE::NiAVObject> model;
			Box box;
			Layer layer;
			bool covered = false;
		};

		// these three are kept for the whole game, models released by a global as the game quits went into a scene
		// graph already torn down
		auto& added = *new std::vector<Kept>();
		bool hidden = false;
		// the menu's movie faded out by another mod's screen over it, kept apart from what the panel hides itself
		bool faded = false;
		// a question of the panel lies over the menu, its whole 3D goes under the picture
		bool allUnder = false;
		// what the game's pass over the picture left out while everything was drawn under it: the model, whether it
		// was out of sight already, whether it was the game's preview of an item
		struct Out
		{
			RE::NiPointer<RE::NiAVObject> model;
			bool culled;
			bool preview;
		};
		auto& passOut = *new std::vector<Out>();
		// a model added while a window lies over its place stays out of sight like the ones there before it
		std::optional<Box> cover;
		constexpr float kFoldedScale = 0.01F;

		void Show(Kept& a_kept)
		{
			a_kept.model->SetAppCulled(a_kept.covered || faded || (hidden && a_kept.layer != Layer::kInspect));
		}

		// A shape with no shader or with every body part of its skin off draws nothing. Physics mods (SMP) keep their
		// collision shapes in an armor's file and leave them on without a shader
		bool Draws(RE::BSGeometry& a_shape)
		{
			const auto& runtime = a_shape.GetGeometryRuntimeData();
			if (!runtime.shaderProperty) {
				return false;
			}
			auto* skin = netimmerse_cast<RE::BSDismemberSkinInstance*>(runtime.skinInstance.get());
			if (!skin || skin->GetRuntimeData().numPartitions <= 0) {
				return true;
			}
			const auto& parts = skin->GetRuntimeData();
			return std::any_of(parts.partitions, parts.partitions + parts.numPartitions, [](const auto& a_part) { return a_part.editorVisible; });
		}

		void Reach(RE::NiAVObject& a_part, bool a_culled, const std::function<void(RE::NiAVObject&)>& a_drawn)
		{
			const bool culled = a_culled || a_part.GetAppCulled();
			if (culled) {
				return;
			}
			if (auto* shape = a_part.AsGeometry(); shape && Draws(*shape)) {
				a_drawn(a_part);
			}
			if (auto* node = a_part.AsNode()) {
				for (const auto& child : node->GetChildren()) {
					if (child) {
						Reach(*child, culled, a_drawn);
					}
				}
			}
		}

		bool Glow(RE::NiAVObject& a_shape)
		{
			const auto& runtime = a_shape.AsGeometry()->GetGeometryRuntimeData();
			return netimmerse_cast<RE::BSEffectShaderProperty*>(runtime.shaderProperty.get()) != nullptr;
		}

		// A glow has no surface to measure: a flame, a halo, the square ENB turns into a lamp. A model is measured by
		// its lit surfaces, its glows count only when it's made of nothing else
		void ReachSurfaces(RE::NiAVObject& a_model, const std::function<void(RE::NiAVObject&)>& a_drawn)
		{
			bool lit = false;
			Reach(a_model, false, [&](RE::NiAVObject& a_shape) { lit = lit || !Glow(a_shape); });
			Reach(a_model, false, [&](RE::NiAVObject& a_shape) {
				if (!lit || !Glow(a_shape)) {
					a_drawn(a_shape);
				}
			});
		}
	}

	Axes Camera()
	{
		// a camera looks along its first axis, the second one is up and the third one is right
		const auto& turn = Lens().world.rotate;
		return { Column(turn, 0), Column(turn, 1), Column(turn, 2) };
	}

	RE::NiPoint3 Eye()
	{
		return Lens().world.translate;
	}

	RE::NiPoint3 Point(float a_fromLeft, float a_fromTop)
	{
		const auto axes = Camera();
		const auto& frustum = Frustum();
		const float across = frustum.fLeft + (frustum.fRight - frustum.fLeft) * a_fromLeft;
		const float along = frustum.fTop + (frustum.fBottom - frustum.fTop) * a_fromTop;
		return Lens().world.translate + (axes.look + axes.right * across + axes.up * along) * Depth();
	}

	std::pair<float, float> Spot(const RE::NiPoint3& a_point)
	{
		const auto axes = Camera();
		const auto& frustum = Frustum();
		const auto away = a_point - Lens().world.translate;
		const float along = away.Dot(axes.look);
		if (along <= 0.0F) {
			return { 0.5F, 0.5F };
		}
		const float across = away.Dot(axes.right) / along;
		const float up = away.Dot(axes.up) / along;
		return { (across - frustum.fLeft) / (frustum.fRight - frustum.fLeft), (up - frustum.fTop) / (frustum.fBottom - frustum.fTop) };
	}

	float Length(float a_shareOfHeight)
	{
		return Depth() * (Frustum().fTop - Frustum().fBottom) * a_shareOfHeight;
	}

	float Aspect()
	{
		const auto& frustum = Frustum();
		return (frustum.fRight - frustum.fLeft) / (frustum.fTop - frustum.fBottom);
	}

	Box Around(float a_centerX, float a_centerY, float a_wide, float a_high)
	{
		const float halfWide = a_wide / Aspect() / 2.0F;
		const float halfHigh = a_high / 2.0F;
		return { a_centerX - halfWide, a_centerY - halfHigh, a_centerX + halfWide, a_centerY + halfHigh };
	}

	RE::NiMatrix3 Columns(const RE::NiPoint3& a_right, const RE::NiPoint3& a_forward, const RE::NiPoint3& a_up)
	{
		RE::NiMatrix3 turn;
		SetColumn(turn, 0, a_right);
		SetColumn(turn, 1, a_forward);
		SetColumn(turn, 2, a_up);
		return turn;
	}

	void Turn(RE::NiAVObject& a_model, const RE::NiPoint3& a_right, const RE::NiPoint3& a_forward, const RE::NiPoint3& a_up)
	{
		a_model.local.rotate = Columns(a_right, a_forward, a_up);
	}

	RE::NiMatrix3 About(const RE::NiPoint3& a_axis, float a_radians)
	{
		const float c = std::cos(a_radians);
		const float s = std::sin(a_radians);
		const float t = 1.0F - c;
		const auto& a = a_axis;
		RE::NiMatrix3 turn;
		turn.entry[0][0] = t * a.x * a.x + c;
		turn.entry[0][1] = t * a.x * a.y - s * a.z;
		turn.entry[0][2] = t * a.x * a.z + s * a.y;
		turn.entry[1][0] = t * a.x * a.y + s * a.z;
		turn.entry[1][1] = t * a.y * a.y + c;
		turn.entry[1][2] = t * a.y * a.z - s * a.x;
		turn.entry[2][0] = t * a.x * a.z - s * a.y;
		turn.entry[2][1] = t * a.y * a.z + s * a.x;
		turn.entry[2][2] = t * a.z * a.z + c;
		return turn;
	}

	void Visit(RE::NiAVObject& a_model, const std::function<void(RE::NiAVObject&)>& a_visit)
	{
		a_visit(a_model);
		if (auto* node = a_model.AsNode()) {
			for (const auto& child : node->GetChildren()) {
				if (child) {
					Visit(*child, a_visit);
				}
			}
		}
	}

	void DropCollision(RE::NiAVObject& a_model)
	{
		Visit(a_model, [](RE::NiAVObject& a_part) { a_part.collisionObject.reset(); });
	}

	namespace
	{
		float FromHalf(std::uint16_t a_bits)
		{
			const std::uint32_t sign = static_cast<std::uint32_t>(a_bits & 0x8000U) << 16;
			const std::uint32_t exponent = (a_bits >> 10) & 0x1FU;
			const std::uint32_t mantissa = a_bits & 0x3FFU;
			if (exponent == 0) {
				const float tiny = std::ldexp(static_cast<float>(mantissa), -24);
				return sign ? -tiny : tiny;
			}
			const std::uint32_t bits = exponent == 31 ? sign | 0x7F800000U | (mantissa << 13) : sign | ((exponent + 112) << 23) | (mantissa << 13);
			return std::bit_cast<float>(bits);
		}

		// every vertex of a shape the renderer keeps a copy of, placed in the world, false for a shape without one
		bool EachVertex(RE::NiAVObject& a_shape, const std::function<void(const RE::NiPoint3&)>& a_take)
		{
			auto* shape = a_shape.AsTriShape();
			// a dynamic shape (a face) keeps its moving positions apart from this copy, and a copy with no positions
			// has nothing at the offset read below
			auto* data = shape && !a_shape.AsDynamicTriShape() ? shape->GetGeometryRuntimeData().rendererData : nullptr;
			if (!data || !data->rawVertexData || !data->vertexDesc.HasFlag(RE::BSGraphics::Vertex::VF_VERTEX)) {
				return false;
			}
			const auto desc = data->vertexDesc;
			// the size of a vertex in fours of bytes lies in the lowest bits of its description. CommonLib's GetSize
			// counts a position as four floats always, a half precision one is four halves
			const std::uint32_t stride = static_cast<std::uint32_t>(std::bit_cast<std::uint64_t>(desc) & 0xF) * 4;
			const std::uint32_t at = desc.GetAttributeOffset(RE::BSGraphics::Vertex::VA_POSITION);
			// the renderer's copy holds a position as four floats even where the file had no full precision flag
			// (iron boots: stride 28, the flag off, floats), a stride that leaves room for four floats has them
			const bool full = desc.HasFlag(RE::BSGraphics::Vertex::VF_FULLPREC) || stride == RE::BSGraphics::VertexDesc(desc).GetSize();
			const std::uint32_t count = shape->GetTrishapeRuntimeData().vertexCount;
			if (stride == 0 || count == 0) {
				return false;
			}
			for (std::uint32_t i = 0; i < count; ++i) {
				const std::uint8_t* place = data->rawVertexData + static_cast<std::size_t>(i) * stride + at;
				RE::NiPoint3 local;
				if (full) {
					const auto* floats = reinterpret_cast<const float*>(place);
					local = { floats[0], floats[1], floats[2] };
				} else {
					const auto* halves = reinterpret_cast<const std::uint16_t*>(place);
					local = { FromHalf(halves[0]), FromHalf(halves[1]), FromHalf(halves[2]) };
				}
				a_take(a_shape.world * local);
			}
			return true;
		}

		// the spheres a shape is drawn within, a skinned one's from its bones: every bone knows the sphere of the
		// vertices it moves, in its own space. A bone with no node of its own (fingers on the game's skeleton) is
		// reached through the place the skin draws it from
		void EachSphere(RE::NiAVObject& a_shape, const std::function<void(const RE::NiPoint3&, float, const char*)>& a_take)
		{
			auto* skin = a_shape.AsGeometry()->GetGeometryRuntimeData().skinInstance.get();
			auto* data = skin ? skin->skinData.get() : nullptr;
			if (!data || !skin->bones) {
				if (a_shape.worldBound.radius > 0.0F) {
					a_take(a_shape.worldBound.center, a_shape.worldBound.radius, "its own bound");
				}
				return;
			}
			for (std::uint32_t at = 0; at < data->GetBoneCount(); ++at) {
				const auto* bone = skin->bones[at];
				const RE::NiTransform* place = skin->boneWorldTransforms && skin->boneWorldTransforms[at] ? skin->boneWorldTransforms[at] : (bone ? &bone->world : nullptr);
				// a bone folded to nothing takes its vertices with it
				if (!place || data->GetBoneDataVerts(at) == 0 || place->scale < kFoldedScale) {
					continue;
				}
				const auto& bound = data->GetBoneDataBound(at);
				a_take(*place * bound.center, bound.radius * place->scale, bone ? bone->name.c_str() : "a bone of the flat list");
			}
		}
	}

	std::vector<RE::NiPoint3> Outline(RE::NiAVObject& a_model)
	{
		const auto axes = Camera();
		const auto from = a_model.world.translate;
		std::vector<RE::NiPoint3> points;
		ReachSurfaces(a_model, [&](RE::NiAVObject& a_shape) {
			const bool skinned = a_shape.AsGeometry()->GetGeometryRuntimeData().skinInstance != nullptr;
			if (!skinned && EachVertex(a_shape, [&](const RE::NiPoint3& a_point) { points.push_back(a_point - from); })) {
				return;
			}
			// eight points round each sphere, so it keeps its size whichever way the model turns
			EachSphere(a_shape, [&](const RE::NiPoint3& a_center, float a_radius, const char*) {
				const float slant = std::numbers::sqrt2_v<float> / 2.0F;
				for (const auto& way : { axes.right, axes.right * -1.0F, axes.up, axes.up * -1.0F, (axes.right + axes.up) * slant, (axes.right - axes.up) * slant,
						 (axes.up - axes.right) * slant, (axes.right + axes.up) * -slant }) {
					points.push_back(a_center + way * a_radius - from);
				}
			});
		});
		return points;
	}

	Extent Measure(RE::NiAVObject& a_model)
	{
		const auto axes = Camera();
		float leftMost = std::numeric_limits<float>::max(), rightMost = -leftMost;
		float lowest = leftMost, highest = -leftMost;
		float deep = 0.0F;
		std::size_t spheres = 0;
		ReachSurfaces(a_model, [&](RE::NiAVObject& a_shape) {
			EachSphere(a_shape, [&](const RE::NiPoint3& a_center, float a_radius, const char*) {
				const float across = a_center.Dot(axes.right);
				const float along = a_center.Dot(axes.up);
				leftMost = std::min(leftMost, across - a_radius);
				rightMost = std::max(rightMost, across + a_radius);
				lowest = std::min(lowest, along - a_radius);
				highest = std::max(highest, along + a_radius);
				deep += a_center.Dot(axes.look);
				++spheres;
			});
		});

		Extent extent;
		if (spheres == 0) {
			return extent;
		}
		extent.found = true;
		extent.wide = rightMost - leftMost;
		extent.high = highest - lowest;
		extent.middle = axes.right * ((leftMost + rightMost) / 2.0F) + axes.up * ((lowest + highest) / 2.0F) + axes.look * (deep / static_cast<float>(spheres));
		return extent;
	}

	std::string TellMeasure(RE::NiAVObject& a_model)
	{
		constexpr std::size_t kTold = 4;
		const auto extent = Measure(a_model);
		const auto axes = Camera();
		struct Sphere
		{
			float reach;
			float radius;
			std::string bone;
			std::string shape;
		};
		std::vector<Sphere> spheres;
		ReachSurfaces(a_model, [&](RE::NiAVObject& a_shape) {
			EachSphere(a_shape, [&](const RE::NiPoint3& a_center, float a_radius, const char* a_bone) {
				const auto off = a_center - extent.middle;
				const float across = off.Dot(axes.right);
				const float along = off.Dot(axes.up);
				spheres.push_back({ std::sqrt(across * across + along * along) + a_radius, a_radius, a_bone ? a_bone : "", a_shape.name.c_str() ? a_shape.name.c_str() : "" });
			});
		});
		std::ranges::sort(spheres, std::greater{}, &Sphere::reach);
		std::string told = std::format("{} spheres, {:.1f} x {:.1f}", spheres.size(), extent.wide, extent.high);
		for (std::size_t i = 0; i < spheres.size() && i < kTold; ++i) {
			told += std::format("{} {} of {} reaches {:.1f}, radius {:.1f}", i ? "," : ", farthest", spheres[i].bone, spheres[i].shape, spheres[i].reach, spheres[i].radius);
		}
		return told;
	}

	void Add(RE::NiAVObject& a_model, const Box& a_box, Layer a_layer)
	{
		IR_BRACKET("the model {} {} goes into the menu's scene, layer {}, {} there before", a_model.name.c_str() ? a_model.name.c_str() : "", static_cast<const void*>(&a_model),
			std::to_underlying(a_layer), added.size());
		Profile::Made(Profile::Held::kSceneModels);
		auto& kept = added.emplace_back(Kept{ RE::NiPointer<RE::NiAVObject>(&a_model), a_box, a_layer });
		kept.covered = a_layer == Layer::kPanel && cover && a_box.Meets(*cover);
		Show(kept);

		RE::UI3DSceneManager::GetSingleton()->AttachChild(&a_model, RE::INTERFACE_LIGHT_SCHEME::kInventory);
		RE::NiUpdateData update;
		a_model.Update(update);
	}

	void Remove(RE::NiAVObject& a_model)
	{
		IR_BRACKET("the model {} {} leaves the menu's scene", a_model.name.c_str() ? a_model.name.c_str() : "", static_cast<const void*>(&a_model));
		auto* scene = RE::UI3DSceneManager::GetSingleton();
		scene->DetachChild(&a_model);

		// the scene lets go of a model only while its menu is up, and models are taken away as the menu closes
		{
			const RE::BSSpinLockGuard locker(scene->lock);
			if (a_model.parent) {
				a_model.parent->DetachChild(&a_model);
			}
		}
		const auto taken = std::erase_if(added, [&](const auto& a_kept) { return a_kept.model.get() == &a_model; });
		Profile::Freed(Profile::Held::kSceneModels, static_cast<std::int64_t>(taken));
	}

	void Hide(bool a_hidden)
	{
		hidden = a_hidden;
		for (auto& kept : added) {
			Show(kept);
		}
	}

	void Fade()
	{
		// a follower's trade may lie under an inventory a script opened over it, the item menu on top is the one in
		// sight and its fade counts
		const RE::IMenu* top = nullptr;
		if (auto* ui = RE::UI::GetSingleton()) {
			const std::array<const RE::IMenu*, 4> ours{ ui->GetMenu<RE::InventoryMenu>().get(), ui->GetMenu<RE::ContainerMenu>().get(),
				ui->GetMenu<RE::BarterMenu>().get(), ui->GetMenu<RE::MagicMenu>().get() };
			for (const auto& menu : ui->menuStack) {
				if (menu && std::ranges::find(ours, menu.get()) != ours.end()) {
					top = menu.get();
				}
			}
		}
		RE::GFxValue alpha;
		const bool now = top && top->uiMovie && top->uiMovie->GetVariable(&alpha, "_root._alpha") && alpha.IsNumber() && alpha.GetNumber() <= 0.0;
		if (now == faded) {
			return;
		}
		faded = now;
		if (faded) {
			logger::info("another mod faded the menu's movie out under a screen of its own, the panel's 3D steps out");
		} else {
			logger::info("the menu's movie is in sight again, the panel's 3D comes back");
		}
		for (auto& kept : added) {
			Show(kept);
		}
	}

	void Cover(const Box& a_box)
	{
		cover = a_box;
		for (auto& kept : added) {
			kept.covered = kept.layer == Layer::kPanel && kept.box.Meets(a_box);
			Show(kept);
		}
	}

	void Uncover()
	{
		cover.reset();
		for (auto& kept : added) {
			kept.covered = false;
			Show(kept);
		}
	}

	// The inventory draws its picture first and its whole 3D scene over it, item previews and all (function 51849 of
	// 1.7.104 calls the picture, then the render of Inventory3DManager). Here that render runs once more before the
	// picture with only the doll in sight. Its other work, a finished load and the item's own animation by the
	// clock, the first call already does. Everything of the menu's 3D drawn before its picture with the game's own
	// call, and left out of the game's pass over the picture
	bool DrawAllUnder(RE::UI3DSceneManager& a_scene)
	{
		RE::Inventory3DManager::GetSingleton()->Render();
		const RE::BSSpinLockGuard locker(a_scene.lock);
		for (const auto& node : a_scene.menuObjects) {
			if (!node) {
				continue;
			}
			for (const auto& child : node->GetChildren()) {
				if (child) {
					passOut.push_back({ child, child->GetAppCulled(), HeldPreview(*child) });
					child->SetAppCulled(true);
				}
			}
		}
		return true;
	}

	bool DrawUnder()
	{
		// kept between frames so a frame doesn't ask the heap for them
		static std::vector<RE::NiAVObject*> under;
		static std::vector<std::pair<RE::NiPointer<RE::NiAVObject>, bool>> others;
		static std::vector<RE::NiAVObject*> previews;
		under.clear();
		previews.clear();
		auto* scene = RE::UI3DSceneManager::GetSingleton();
		if (allUnder) {
			return DrawAllUnder(*scene);
		}
		for (const auto& kept : added) {
			if (kept.layer == Layer::kUnder && !kept.model->GetAppCulled()) {
				under.push_back(kept.model.get());
			}
		}
		if (under.empty()) {
			return false;
		}
		{
			const RE::BSSpinLockGuard locker(scene->lock);
			for (const auto& node : scene->menuObjects) {
				if (!node) {
					continue;
				}
				for (const auto& child : node->GetChildren()) {
					if (child && std::ranges::find(under, child.get()) == under.end()) {
						others.emplace_back(child, child->GetAppCulled());
						child->SetAppCulled(true);
					}
				}
			}
		}
		for (const auto& loaded : RE::Inventory3DManager::GetSingleton()->GetRuntimeData().loadedModels) {
			if (loaded.spModel) {
				previews.push_back(loaded.spModel.get());
			}
		}
		RE::Inventory3DManager::GetSingleton()->Render();
		{
			const RE::BSSpinLockGuard locker(scene->lock);
			for (const auto& [model, culled] : others) {
				// a load the pass finished can let the preview of the last item go, it isn't brought back here
				if (!culled && std::ranges::find(previews, model.get()) != previews.end() && !HeldPreview(*model)) {
					continue;
				}
				model->SetAppCulled(culled);
			}
			for (auto* model : under) {
				model->SetAppCulled(true);
			}
		}
		static std::atomic<bool> told{ false };
		if (!told.exchange(true)) {
			logger::info("the doll is drawn under the picture of the menu, {} other models wait for the pass over it", others.size());
		}
		others.clear();
		return true;
	}

	void AddHidden(RE::NiAVObject& a_model)
	{
		// whatever the screen shows now, an item menu or the loading screen, its lights stay as they are
		auto* scene = RE::UI3DSceneManager::GetSingleton();
		scene->AttachChild(&a_model, scene->currentlightScheme);
		a_model.SetAppCulled(true);
	}

	void DrawAlone(RE::NiAVObject& a_model, bool a_shown)
	{
		auto* scene = RE::UI3DSceneManager::GetSingleton();
		std::vector<std::pair<RE::NiPointer<RE::NiAVObject>, bool>> out;
		{
			const RE::BSSpinLockGuard locker(scene->lock);
			for (const auto& node : scene->menuObjects) {
				if (!node) {
					continue;
				}
				for (const auto& child : node->GetChildren()) {
					if (child && child.get() != &a_model) {
						out.emplace_back(child, child->GetAppCulled());
						child->SetAppCulled(true);
					}
				}
			}
		}
		a_model.SetAppCulled(!a_shown);
		RE::Inventory3DManager::GetSingleton()->Render();
		a_model.SetAppCulled(true);
		const RE::BSSpinLockGuard locker(scene->lock);
		for (const auto& [model, culled] : out) {
			model->SetAppCulled(culled);
		}
	}

	EvenAmbient::EvenAmbient(float a_level)
	{
		if (!(a_level > 0.0F)) {
			return;
		}
		auto& state = RE::BSShaderManager::State::GetSingleton();
		kept = state.directionalAmbientTransform;
		for (auto& row : state.directionalAmbientTransform.rotate.entry) {
			std::ranges::fill(row, 0.0F);
		}
		state.directionalAmbientTransform.translate = { a_level, a_level, a_level };
	}

	EvenAmbient::~EvenAmbient()
	{
		if (kept) {
			RE::BSShaderManager::State::GetSingleton().directionalAmbientTransform = *kept;
		}
	}

	// With temporal anti-aliasing the game blends the menu's 3D with the one of the frame before. Two passes a
	// frame would each take the other's picture for the frame before, the slot models and the preview never
	// found themselves in it and shimmered. The doll keeps the blending, the game's own pass over the menu
	// goes without it
	TemporalBlend::TemporalBlend(bool a_kept)
	{
		auto* imageSpace = RE::ImageSpaceManager::GetSingleton();
		temporal = imageSpace ? imageSpace->GetRuntimeData().BSImagespaceShaderISTemporalAA : nullptr;
		blended = temporal && temporal->taaEnabled;
		if (temporal && !a_kept) {
			temporal->taaEnabled = false;
		}
	}

	TemporalBlend::~TemporalBlend()
	{
		if (temporal) {
			temporal->taaEnabled = blended;
		}
	}

	ScreenLights::ScreenLights()
	{
		auto* manager = RE::Inventory3DManager::GetSingleton();
		kept = manager->currentLightScheme;
		manager->currentLightScheme = RE::UI3DSceneManager::GetSingleton()->currentlightScheme;
	}

	ScreenLights::~ScreenLights()
	{
		RE::Inventory3DManager::GetSingleton()->currentLightScheme = kept;
	}

	void DrawnUnder()
	{
		for (auto& kept : added) {
			if (kept.layer == Layer::kUnder) {
				Show(kept);
			}
		}
		if (passOut.empty()) {
			return;
		}
		auto* scene = RE::UI3DSceneManager::GetSingleton();
		const RE::BSSpinLockGuard locker(scene->lock);
		for (const auto& out : passOut) {
			// a load the game's pass finished let the preview of the last item go, it stays gone
			if (!out.culled && out.preview && !HeldPreview(*out.model)) {
				continue;
			}
			out.model->SetAppCulled(out.culled);
		}
		passOut.clear();
	}

	void AllUnder(bool a_under)
	{
		allUnder = a_under;
	}

	namespace
	{
		bool previewShown = true;
		// only what was put out of sight here comes back, the game hides models of its own too
		auto& previewsHidden = *new std::vector<RE::NiPointer<RE::NiAVObject>>();

		// The model of another item can stand over the one in the item window. The log tells each time the game
		// starts to hold the previews of more than one model, with the item and model of each and which are hidden
		void TellPreviews()
		{
			static std::size_t told = 1;
			const auto& loaded = RE::Inventory3DManager::GetSingleton()->GetRuntimeData().loadedModels;
			std::size_t held = 0;
			for (const auto& one : loaded) {
				held += one.spModel ? 1 : 0;
			}
			if (held != told && held > 1) {
				std::string items;
				for (const auto& one : loaded) {
					if (one.spModel) {
						items += fmt::format(" {:08X}/{:08X}{}", one.itemBase ? one.itemBase->GetFormID() : 0, one.modelObj ? one.modelObj->GetFormID() : 0,
							one.spModel->GetAppCulled() ? " hidden" : "");
					}
				}
				logger::info("the game holds {} item previews:{}", held, items);
			}
			told = held;
		}
	}

	bool HeldPreview(const RE::NiAVObject& a_model)
	{
		for (const auto& loaded : RE::Inventory3DManager::GetSingleton()->GetRuntimeData().loadedModels) {
			if (loaded.spModel.get() == &a_model) {
				return true;
			}
		}
		return false;
	}

	namespace
	{
		// the magic menu keeps the spell itself as the item of its preview. Without it a spell's model the window took
		// away while the pointer was off the rows never came back, every other spell showed none
		const RE::TESForm* SelectedItem()
		{
			auto* ui = RE::UI::GetSingleton();
			if (const auto magic = ui->GetMenu<RE::MagicMenu>(); magic && !ui->IsMenuOpen(RE::InventoryMenu::MENU_NAME)) {
				auto* spells = magic->GetRuntimeData().itemList;
				auto* spell = spells ? spells->GetSelectedItem() : nullptr;
				return spell ? spell->data.baseForm : nullptr;
			}
			RE::ItemList* list = nullptr;
			if (const auto menu = ui->GetMenu<RE::InventoryMenu>()) {
				list = menu->GetRuntimeData().itemList;
			} else if (const auto container = ui->GetMenu<RE::ContainerMenu>()) {
				list = container->GetRuntimeData().itemList;
			} else if (const auto barter = ui->GetMenu<RE::BarterMenu>()) {
				list = barter->GetRuntimeData().itemList;
			}
			auto* item = list ? list->GetSelectedItem() : nullptr;
			auto* entry = item ? item->data.objDesc : nullptr;
			return entry ? entry->object : nullptr;
		}
	}

	bool SelectedPreview(const RE::NiAVObject& a_model)
	{
		const auto* selected = SelectedItem();
		for (const auto& loaded : RE::Inventory3DManager::GetSingleton()->GetRuntimeData().loadedModels) {
			if (loaded.spModel.get() == &a_model) {
				return selected && loaded.itemBase == selected;
			}
		}
		return false;
	}

	void ShowPreview(bool a_shown)
	{
		previewShown = a_shown;
	}

	// While an item is inspected (the scene hidden) every preview stays out of sight too: the game puts the model of a
	// row it selects anew back up, and the window's model stood over the inspected item
	void KeepPreview()
	{
		TellPreviews();
		if (previewShown && !hidden && !faded) {
			// while the window was away the selection may have moved on, the game hid the old model itself then.
			// Only the model of the item selected now comes back, else it stood over the next item's
			for (auto& model : previewsHidden) {
				if (SelectedPreview(*model)) {
					model->SetAppCulled(false);
				}
			}
			previewsHidden.clear();
			return;
		}
		for (const auto& loaded : RE::Inventory3DManager::GetSingleton()->GetRuntimeData().loadedModels) {
			auto* model = loaded.spModel.get();
			if (model && !model->GetAppCulled()) {
				model->SetAppCulled(true);
				previewsHidden.emplace_back(model);
			}
		}
	}
}
