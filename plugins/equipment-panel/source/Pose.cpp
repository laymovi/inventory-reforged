#include "PCH.h"

#include "Pose.h"

#include "Scene.h"
#include "Settings.h"
#include "StandingPose.h"

#ifndef WIN32_LEAN_AND_MEAN
#	define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#	define NOMINMAX
#endif
#include <Windows.h>

namespace Pose
{
	namespace
	{
		constexpr std::string_view kBonePrefix = "NPC ";
		// riding or sitting moves the body down, these get the place of the pose as well as its turn
		constexpr std::array kPlaced{ "NPC Root [Root]"sv, "NPC COM [COM ]"sv };
	}

	namespace
	{
		std::span<const StandingPose::Bone> PoseOf(bool a_female, bool a_torch)
		{
			if (a_torch) {
				return a_female && !StandingPose::kFemaleTorch.empty() ? std::span<const StandingPose::Bone>(StandingPose::kFemaleTorch) :
				                                                         std::span<const StandingPose::Bone>(StandingPose::kMaleTorch);
			}
			return a_female && !StandingPose::kFemale.empty() ? std::span<const StandingPose::Bone>(StandingPose::kFemale) : std::span<const StandingPose::Bone>(StandingPose::kMale);
		}
	}

	bool HoldsTorch(RE::Actor& a_actor)
	{
		const auto* left = a_actor.GetEquippedObject(true);
		return left && left->Is(RE::FormType::Light);
	}

	namespace
	{
		std::size_t PutOn(RE::NiAVObject& a_copy, std::span<const StandingPose::Bone> a_bones)
		{
			std::size_t posed = 0;
			for (const auto& bone : a_bones) {
				auto* node = a_copy.GetObjectByName(RE::BSFixedString(bone.name));
				if (!node) {
					continue;
				}
				for (std::size_t row = 0; row < 3; ++row) {
					for (std::size_t column = 0; column < 3; ++column) {
						node->local.rotate.entry[row][column] = bone.turn[row * 3 + column];
					}
				}
				if (std::ranges::find(kPlaced, bone.name) != kPlaced.end()) {
					node->local.translate = { bone.place[0], bone.place[1], bone.place[2] };
				}
				++posed;
			}
			return posed;
		}
	}

	bool Stand(RE::NiAVObject& a_copy, bool a_female, bool a_torch)
	{
		const auto posed = PutOn(a_copy, PoseOf(a_female, false));
		// the arm of the torch goes over the calm one, the rest of the body stands the same
		if (posed > 0 && a_torch) {
			PutOn(a_copy, PoseOf(a_female, true));
		}
		return posed > 0;
	}

	namespace
	{
		// the skeleton file of the actor's race and sex as the game keeps it, main thread only
		RE::NiPointer<RE::NiNode> AtRest(RE::Actor& a_actor)
		{
			auto* race = a_actor.GetRace();
			const auto* base = a_actor.GetActorBase();
			const char* path = race && base ? race->skeletonModels[base->GetSex()].GetModel() : nullptr;
			RE::NiPointer<RE::NiNode> atRest;
			const RE::BSModelDB::DBTraits::ArgsType how;
			IR_BRACKET("the skeleton {} is read", path ? path : "");
			if (!path || !*path || RE::BSModelDB::Demand(path, atRest, how) != RE::BSResource::ErrorCode::kNone) {
				return nullptr;
			}
			return atRest;
		}
	}

	// The props of an animation (a smith's hammer and tongs, a tankard) hang under the AnimObject nodes of the skeleton, a
	// doll standing calm holds none of them
	void DropProps(RE::NiAVObject& a_copy)
	{
		Scene::Visit(a_copy, [](RE::NiAVObject& a_part) {
			const std::string_view name = a_part.name.c_str() ? a_part.name.c_str() : "";
			if (a_part.AsNode() && name.starts_with("AnimObject")) {
				a_part.SetAppCulled(true);
			}
		});
	}

	// At a crafting station the body works under the menu. The bones the standing pose leaves alone (wrists, fingers,
	// the pauldrons of a skeleton mod) came from another moment of the swing with every copy. They take the turn the
	// skeleton file rests in
	void Settle(RE::NiAVObject& a_copy, RE::Actor& a_actor, bool a_female, bool a_torch)
	{
		const auto atRest = AtRest(a_actor);
		if (!atRest) {
			return;
		}
		std::set<std::string_view> posed;
		for (const auto& bone : PoseOf(a_female, false)) {
			posed.insert(bone.name);
		}
		if (a_torch) {
			for (const auto& bone : PoseOf(a_female, true)) {
				posed.insert(bone.name);
			}
		}
		Scene::Visit(a_copy, [&](RE::NiAVObject& a_part) {
			auto* tree = netimmerse_cast<RE::BSFlattenedBoneTree*>(&a_part);
			if (!tree) {
				return;
			}
			auto& lists = tree->GetRuntimeData();
			for (std::uint32_t i = 0; lists.boneEntries && i < lists.numBones; ++i) {
				auto& entry = lists.boneEntries[i];
				const char* name = entry.nodeName.c_str();
				if (!name || !*name || posed.contains(name)) {
					continue;
				}
				const auto* rest = atRest->GetObjectByName(entry.nodeName);
				if (!rest) {
					continue;
				}
				entry.local.rotate = rest->local.rotate;
				if (entry.node) {
					entry.node->local.rotate = rest->local.rotate;
				}
			}
		});
	}

	namespace
	{
		std::unordered_map<std::string, RE::NiPoint3> steadyPlaces;
		RE::FormID steadyFor = 0;
	}

	// The doll at a station is copied every 300 ms for 3 s after a piece is tried on, and bones the physics or the
	// work at the forge move took a new place with each copy. The first copy of a person in a station's visit gives
	// each bone its place and the copies after keep it. Their turns already rest (Settle)
	void Steady(RE::NiAVObject& a_copy, RE::Actor& a_actor)
	{
		if (std::exchange(steadyFor, a_actor.GetFormID()) != a_actor.GetFormID()) {
			steadyPlaces.clear();
		}
		Scene::Visit(a_copy, [&](RE::NiAVObject& a_part) {
			auto* tree = netimmerse_cast<RE::BSFlattenedBoneTree*>(&a_part);
			if (!tree) {
				return;
			}
			auto& lists = tree->GetRuntimeData();
			for (std::uint32_t i = 0; lists.boneEntries && i < lists.numBones; ++i) {
				auto& entry = lists.boneEntries[i];
				const char* name = entry.nodeName.c_str();
				if (!name || !*name || std::ranges::find(kPlaced, std::string_view(name)) != kPlaced.end()) {
					continue;
				}
				const auto& place = entry.node ? entry.node->local.translate : entry.local.translate;
				const auto [kept, fresh] = steadyPlaces.try_emplace(name, place);
				if (!fresh) {
					entry.local.translate = kept->second;
					if (entry.node) {
						entry.node->local.translate = kept->second;
					}
				}
			}
		});
	}

	void Unsteady()
	{
		steadyPlaces.clear();
		steadyFor = 0;
	}

	// Tells the bones that moved since the last copy, the place in units and the largest change of a turn
	void TellDrift(RE::NiAVObject& a_copy)
	{
		static std::unordered_map<std::string, RE::NiTransform> last;
		std::unordered_map<std::string, RE::NiTransform> now;
		Scene::Visit(a_copy, [&](RE::NiAVObject& a_part) {
			auto* tree = netimmerse_cast<RE::BSFlattenedBoneTree*>(&a_part);
			if (!tree) {
				return;
			}
			auto& lists = tree->GetRuntimeData();
			for (std::uint32_t i = 0; lists.boneEntries && i < lists.numBones; ++i) {
				const auto& entry = lists.boneEntries[i];
				const char* name = entry.nodeName.c_str();
				if (name && *name) {
					now[name] = entry.node ? entry.node->local : entry.local;
				}
			}
		});
		std::vector<std::pair<float, std::string>> moved;
		for (const auto& [name, place] : now) {
			const auto before = last.find(name);
			if (before == last.end()) {
				continue;
			}
			float turn = 0.0F;
			for (std::size_t row = 0; row < 3; ++row) {
				for (std::size_t column = 0; column < 3; ++column) {
					turn = std::max(turn, std::abs(place.rotate.entry[row][column] - before->second.rotate.entry[row][column]));
				}
			}
			const float shift = place.translate.GetDistance(before->second.translate);
			if (shift > 0.01F || turn > 0.001F) {
				moved.emplace_back(shift + turn * 10.0F, std::format("{} {:.2f}/{:.3f}", name, shift, turn));
			}
		}
		last = std::move(now);
		if (moved.empty()) {
			return;
		}
		std::ranges::sort(moved, std::greater{});
		std::string told;
		for (std::size_t i = 0; i < moved.size() && i < 8; ++i) {
			told += (i ? ", " : "") + moved[i].second;
		}
		logger::info("the doll's bones moved since the last copy, {} of them, place/turn: {}", moved.size(), told);
	}

	bool KeepsWorldPose()
	{
		const auto* camera = RE::PlayerCamera::GetSingleton();
		return Settings::Get().pose == Settings::Pose::kAsInWorld && !(camera && camera->IsInFirstPerson());
	}

	void LookAhead(RE::NiAVObject& a_copy, RE::Actor& a_player)
	{
		static constexpr std::array turning{ "NPC Spine [Spn0]", "NPC Spine1 [Spn1]", "NPC Spine2 [Spn2]", "NPC Neck [Neck]", "NPC Head [Head]" };

		const auto atRest = AtRest(a_player);
		if (!atRest) {
			return;
		}
		for (const char* name : turning) {
			auto* bone = a_copy.GetObjectByName(name);
			const auto* resting = atRest->GetObjectByName(name);
			if (bone && resting) {
				bone->local.rotate = resting->local.rotate;
			}
		}
	}

	void Dump(RE::NiAVObject& a_body, bool a_female, bool a_torch)
	{
		const auto folder = SKSE::log::log_directory();
		if (!folder) {
			return;
		}
		std::ofstream file(*folder / std::format("InventoryReforged-pose-{}{}.txt", a_female ? "female" : "male", a_torch ? "-torch" : ""));
		std::size_t bones = 0;
		Scene::Visit(a_body, [&](RE::NiAVObject& a_part) {
			const std::string_view name = a_part.name.c_str() ? a_part.name.c_str() : "";
			if (!a_part.AsNode() || !name.starts_with(kBonePrefix)) {
				return;
			}
			const auto& turn = a_part.local.rotate.entry;
			const auto& place = a_part.local.translate;
			file << name << '|';
			for (const auto& row : turn) {
				file << std::format("{:.6f} {:.6f} {:.6f} ", row[0], row[1], row[2]);
			}
			file << std::format("|{:.4f} {:.4f} {:.4f}\n", place.x, place.y, place.z);
			++bones;
		});
		logger::info("the pose of {} bones is written for a {} body{}", bones, a_female ? "female" : "male", a_torch ? " with a torch" : "");
	}

	void Tell(RE::NiAVObject& a_body, RE::NiAVObject& a_copy, RE::Actor& a_shown)
	{
		static constexpr std::array bones{ "NPC Pelvis [Pelv]", "NPC Spine [Spn0]", "NPC Spine1 [Spn1]", "NPC Spine2 [Spn2]", "NPC Neck [Neck]",
			"NPC Head [Head]", "NPC L Clavicle [LClv]", "NPC L UpperArm [LUar]", "NPC L Forearm [LLar]", "NPC L Hand [LHnd]", "NPC L Thigh [LThg]",
			"NPC L Calf [LClf]", "NPC L Foot [Lft ]" };
		static std::string told;
		const auto atRest = AtRest(a_shown);
		// each bone as its offset from its parent and its own size, the parts of a reading that tell a squeezed spine
		const auto of = [](RE::NiAVObject* a_root, const char* a_name) {
			const auto* bone = a_root ? a_root->GetObjectByName(a_name) : nullptr;
			return bone ? std::format("{:.1f}x{:.2f}", bone->local.translate.Length(), bone->local.scale) : std::string("-");
		};
		std::string reading;
		for (const char* name : bones) {
			reading += std::format(" {} {}/{}/{}", std::string_view(name).substr(4), of(&a_body, name), of(&a_copy, name), of(atRest.get(), name));
		}
		const auto* camera = RE::PlayerCamera::GetSingleton();
		const bool firstPerson = camera && camera->IsInFirstPerson();
		const bool improved = GetModuleHandleW(L"ImprovedCameraSE.dll") != nullptr;
		reading += std::format("; {} person, Improved Camera {}, scale {:.2f}, the doll {}", firstPerson ? "first" : "third", improved ? "loaded" : "absent", a_shown.GetScale(),
			KeepsWorldPose() ? "as in the world" : "standing");
		if (reading == told) {
			return;
		}
		told = reading;
		logger::info("bones of {}, offset x size in the body/doll/race skeleton:{}", a_shown.GetName(), reading);
	}
}
