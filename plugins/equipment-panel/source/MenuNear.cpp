#include "PCH.h"

#include "MenuNear.h"

#include "Scene.h"

namespace MenuNear
{
	namespace
	{
		// the plane stops this share of the way to the nearest bound, room for the bounds of skinned parts that run short
		constexpr float kRoom = 0.7F;

		// how far along the look the nearest model the menu shows starts, by the bounds of what is in sight
		float Nearest(const RE::NiAVObject& a_eye)
		{
			const auto look = Scene::Camera().look;
			float nearest = std::numeric_limits<float>::max();
			auto* scene = RE::UI3DSceneManager::GetSingleton();
			const RE::BSSpinLockGuard locker(scene->lock);
			for (const auto& node : scene->menuObjects) {
				if (!node) {
					continue;
				}
				for (const auto& child : node->GetChildren()) {
					if (!child || child->GetAppCulled() || child->worldBound.radius <= 0.0F) {
						continue;
					}
					const auto& bound = child->worldBound;
					nearest = std::min(nearest, (bound.center - a_eye.world.translate).Dot(look) - bound.radius);
				}
			}
			return nearest;
		}
	}

	Closer::Closer(std::int32_t a_setting)
	{
		if (a_setting == kGameNear) {
			return;
		}
		auto* lens = RE::UI3DSceneManager::GetSingleton()->camera.get();
		if (!lens) {
			return;
		}
		auto& frustum = lens->GetRuntimeData2().viewFrustum;
		const float wanted = a_setting > kAuto ? static_cast<float>(a_setting) : Nearest(*lens) * kRoom;
		// on its own the plane only ever comes closer to the models, a set one is there to try either way
		if (!(wanted > 0.0F) || !(wanted < frustum.fFar) || (a_setting == kAuto && !(wanted > frustum.fNear))) {
			return;
		}
		static std::atomic<bool> told{ false };
		if (!told.exchange(true)) {
			logger::info("the menus' 3D draws with its near plane at {:.1f} in place of {:.1f}, far {:.0f}", wanted, frustum.fNear, frustum.fFar);
		}
		kept = frustum.fNear;
		frustum.fNear = wanted;
		camera = lens;
	}

	Closer::~Closer()
	{
		if (camera) {
			camera->GetRuntimeData2().viewFrustum.fNear = kept;
		}
	}
}
