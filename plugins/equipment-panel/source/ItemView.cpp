#include "PCH.h"

#include "ItemView.h"

#include "Copy.h"
#include "Inspect.h"
#include "People.h"
#include "Profile.h"
#include "Scene.h"
#include "Settings.h"
#include "Subject.h"
#include "WornView.h"

#include <deque>

namespace ItemView
{
	namespace
	{
		// A model shown only while its row is selected lived a few milliseconds when rows went by fast, and the textures
		// only it held died with it. The game streams textures in after the model and never drops one that young, a
		// texture that died while its data was still coming in took the game down later in its texture base. So a model
		// the menu lets go rests a few seconds before its last pointer goes, a file model pushed out of the cache too.
		// Only age lets one go, a cap on the count dropped young ones again when rows went by faster than about fifty a
		// second. One release a frame at most comes from the window, so a few hundred rest at worst
		constexpr auto kRest = std::chrono::seconds(5);
		// kept for the whole game on purpose: models released by a global as the game quits went into a scene graph
		// already torn down
		auto& resting = *new std::deque<std::pair<std::chrono::steady_clock::time_point, RE::NiPointer<RE::NiObject>>>();

		void Bury()
		{
			const auto now = std::chrono::steady_clock::now();
			while (!resting.empty() && now - resting.front().first >= kRest) {
				resting.pop_front();
			}
		}

		void Rest(RE::NiObject* a_model)
		{
			if (a_model) {
				resting.emplace_back(std::chrono::steady_clock::now(), RE::NiPointer<RE::NiObject>{ a_model });
			}
			Bury();
		}

		// share of the screen height the game's preview takes at the scale the game starts with
		constexpr float kPreviewShareAtGameScale = 0.45F;
		constexpr float kLeanDegrees = 45.0F;
		// worn pieces turn a little so they don't look flat
		constexpr float kWornTurnDegrees = 20.0F;

		enum class Kind
		{
			kItem,
			kFace,
			kBody
		};

		// a file a model may come from, the files of an item are tried in turn until one reads, with the textures its
		// record puts on it
		struct File
		{
			std::string path;
			Kind kind;
			const RE::TESModelTextureSwap* swaps = nullptr;
			// the record a face file belongs to, its skin may hold its hair
			const RE::TESNPC* person = nullptr;
		};

		struct Shown
		{
			Slot slot;
			RE::NiPointer<RE::NiAVObject> model;
			bool asWorn = false;
		};

		auto& shown = *new std::vector<Shown>();
		// worn pieces that gave no worn look, with the make of the body they were tried on
		std::vector<std::pair<RE::FormID, std::size_t>> failed;

		// where the game itself shows item previews, other menus count on it
		struct GamePlace
		{
			RE::NiPoint3 position;
			float scale;
		};
		std::optional<GamePlace> gamePlace;
		// The room the window gave the preview last, shares of the screen height, and its middle in the scene. None while
		// the game keeps its own place
		struct Room
		{
			float wide;
			float high;
			RE::NiPoint3 middle;
			// how many times the game's size the model may grow to fill the room, 0 for the window's own
			float growMost = 0.0F;
			std::optional<ItemView::Corner> corner;
		};
		std::optional<Room> previewRoom;
		std::optional<std::array<float, 4>> previewSeen;
		// the model of a row stands in the game's own place, in front of the doll (the UI's own card)
		bool previewAtHome = false;

		bool HasFile(const RE::TESModel& a_model)
		{
			const auto* path = a_model.GetModel();
			return path && *path;
		}

		RE::TESModel* WorldModel(RE::TESForm& a_item)
		{
			if (auto* armor = a_item.As<RE::TESObjectARMO>()) {
				// most armor has no ground model of its own for women, the game then uses the men's one, and a piece
				// made for women alone (Aegyptus) has the women's one only
				const auto wearer = Subject::Get();
				const auto* base = wearer ? wearer->GetActorBase() : nullptr;
				auto& own = armor->worldModels[base ? base->GetSex() : RE::SEXES::kMale];
				auto& men = armor->worldModels[RE::SEXES::kMale];
				return HasFile(own) ? &own : (HasFile(men) ? &men : &armor->worldModels[RE::SEXES::kFemale]);
			}
			return skyrim_cast<RE::TESModel*>(&a_item);
		}

		// weapons, arrows and shields are modelled lying on the ground, armor is modelled standing
		bool LiesFlat(RE::TESForm& a_item)
		{
			auto* armor = a_item.As<RE::TESObjectARMO>();
			return armor ? armor->HasPartOf(RE::BGSBipedObjectForm::BipedObjectSlot::kShield) : true;
		}

		// Most item models carry a marker that says how to turn them for a menu, the game's own preview follows it.
		// Without one a lying model is seen from above with a blade running from corner to corner. A standing one stays
		// unturned as the game's preview shows it, front to the viewer. Most boots and helmets have no marker, turned to
		// the camera's axes they showed their heels and the back of the head (Steel Cuffed Boots)
		RE::NiMatrix3 Facing(RE::NiAVObject& a_model, bool a_liesFlat)
		{
			RE::NiMatrix3 facing;
			// a lying model's marker turns it a quarter round to lay it flat, every vanilla weapon's does, one turned
			// by nothing was never set
			auto* marker = a_model.GetExtraData<RE::BSInvMarker>("INV");
			const bool unset = marker && a_liesFlat && marker->rotationX == 0 && marker->rotationY == 0 && marker->rotationZ == 0;
			if (marker && !unset) {
				facing.SetEulerAnglesXYZ(marker->GetRotationEulerAnglesXYZ());
				return facing;
			}
			if (!a_liesFlat) {
				return facing;
			}
			const auto camera = Scene::Camera();
			const float lean = kLeanDegrees * std::numbers::pi_v<float> / 180.0F;
			const RE::NiPoint3 across = camera.right * std::cos(lean) + camera.up * std::sin(lean);
			const RE::NiPoint3 along = camera.up * std::cos(lean) - camera.right * std::sin(lean);
			return Scene::Columns(across, along, camera.look * -1.0F);
		}

		// a face is turned a little off the camera, a creature more, so it isn't seen flat from the front
		constexpr float kFaceTurnDegrees = 18.0F;
		constexpr float kCreatureTurnDegrees = 40.0F;
		// the records of one name a face is looked for in, each look is a file asked of the disk
		constexpr std::size_t kFacesTried = 6;

		// The face the game made for the record in the editor: the head with its hair, eyes and paint, one file for
		// each person under the plugin that made it. A record that takes its looks from another one has that one's face.
		// The tint of the skin is a texture of its own the game finds the same way
		std::string FaceFile(const RE::TESNPC& a_person, std::string_view a_folder, std::string_view a_kind)
		{
			const auto* face = a_person.GetRootFaceNPC();
			const auto* file = face ? face->GetFile(0) : nullptr;
			if (!file) {
				return {};
			}
			const auto id = face->GetFormID();
			return std::format("{}\\{}\\{:08X}.{}", a_folder, file->GetFilename(), file->IsLight() ? id & 0xFFF : id & 0xFFFFFF, a_kind);
		}

		std::string FacePath(const RE::TESNPC& a_person)
		{
			return FaceFile(a_person, "Actors\\Character\\FaceGenData\\FaceGeom", "nif");
		}

		// The body of a creature is the model of its skin, the one for its race, standing as it was made. A record that
		// takes its looks from a template has the template's
		const RE::TESModelTextureSwap* BodyModel(const RE::TESNPC& a_record)
		{
			const auto& person = People::TraitsOf(a_record);
			const auto* race = person.race;
			const auto* skin = person.skin ? person.skin : (race ? race->skin : nullptr);
			if (!skin) {
				return nullptr;
			}
			const RE::TESObjectARMA* chosen = nullptr;
			for (const auto* addon : skin->armorAddons) {
				if (!addon) {
					continue;
				}
				const bool fits = addon->race == race || std::ranges::find(addon->additionalRaces, race) != addon->additionalRaces.end();
				if (fits || !chosen) {
					chosen = addon;
				}
				if (fits) {
					break;
				}
			}
			if (!chosen) {
				return nullptr;
			}
			const auto sex = person.GetSex() == RE::SEX::kFemale ? RE::SEXES::kFemale : RE::SEXES::kMale;
			return HasFile(chosen->bipedModels[sex]) ? &chosen->bipedModels[sex] : &chosen->bipedModels[RE::SEXES::kMale];
		}

		// The model the game keeps for a file, read from the disk the first time
		RE::NiPointer<RE::NiNode> FromDisk(const std::string& a_path)
		{
			static const auto reading = Profile::Work("tile model read");
			const Profile::Timer timer{ reading };
			IR_NOTE(timer, "{}", a_path);
			IR_BRACKET("the model {} is read", a_path);
			RE::NiPointer<RE::NiNode> kept;
			const RE::BSModelDB::DBTraits::ArgsType how;
#if IR_DEBUG_EDITION
			if (const auto read = a_path.empty() ? RE::BSResource::ErrorCode::kNotExist : RE::BSModelDB::Demand(a_path.c_str(), kept, how); read != RE::BSResource::ErrorCode::kNone) {
				IR_LOG("the model {} didn't read, error {}", a_path, std::to_underlying(read));
				return nullptr;
			}
#else
			if (a_path.empty() || RE::BSModelDB::Demand(a_path.c_str(), kept, how) != RE::BSResource::ErrorCode::kNone) {
				return nullptr;
			}
#endif
			return kept;
		}

		// The last models read stay with the game, so going back to an entry of the browser costs only the copy. A read
		// on a thread of the plugin took the game down (a model with collision needs the Havok memory of a game thread),
		// and a read put off to a later frame of the menu hung it with Souls RE, so the read stays in the click. They
		// outlive the menu, the same rows on the next open cost no read
		constexpr std::size_t kModelsKept = 64;
		auto& keptModels = *new std::vector<std::pair<std::string, RE::NiPointer<RE::NiNode>>>();

		RE::NiPointer<RE::NiNode> Kept(const std::string& a_path)
		{
			const auto found = std::ranges::find(keptModels, a_path, &std::remove_reference_t<decltype(keptModels)>::value_type::first);
			if (found != keptModels.end()) {
				std::rotate(keptModels.begin(), found, found + 1);
				return keptModels.front().second;
			}
			auto kept = FromDisk(a_path);
			if (kept) {
				keptModels.insert(keptModels.begin(), { a_path, kept });
				if (keptModels.size() > kModelsKept) {
					Rest(keptModels.back().second.get());
					keptModels.pop_back();
				}
			}
			return kept;
		}

		void ForEachShape(RE::NiAVObject& a_part, const std::function<void(RE::NiAVObject&)>& a_take)
		{
			if (a_part.AsGeometry()) {
				a_take(a_part);
			}
			if (auto* node = a_part.AsNode()) {
				for (const auto& child : node->GetChildren()) {
					if (child) {
						ForEachShape(*child, a_take);
					}
				}
			}
		}

		bool FaceItself(RE::NiAVObject& a_shape)
		{
			auto* lighting = netimmerse_cast<RE::BSLightingShaderProperty*>(a_shape.AsGeometry()->GetGeometryRuntimeData().shaderProperty.get());
			const auto* material = lighting ? static_cast<RE::BSLightingShaderMaterialBase*>(lighting->material) : nullptr;
			return material && material->GetFeature() == RE::BSShaderMaterial::Feature::kFaceGen;
		}

		// The bones of a face stand where its parts were made around them. In game the parts hang from the actor's own
		// skeleton, so a face file may keep the bones anywhere: a face of a mod keeps the neck and the head apart and
		// the hair weighed on both tears between them, hair that moves with physics keeps its own bones at the feet of
		// the model. The skin data of each part keeps where every bone stood when the part was made. The face itself
		// goes first and its head stays where the file has it, every bone of the face goes where the face was made
		// around it, then each other part puts the bones it alone has from a bone already put. A bone goes by its name,
		// hair of the skin brings its own copy of the head. A part that shares no bone with the ones put stays out
		void PoseFaceBones(RE::NiAVObject& a_face)
		{
			RE::NiUpdateData update;
			a_face.Update(update);
			std::vector<RE::NiAVObject*> shapes;
			ForEachShape(a_face, [&](RE::NiAVObject& a_shape) { shapes.push_back(&a_shape); });
			std::ranges::stable_partition(shapes, [](RE::NiAVObject* a_shape) { return FaceItself(*a_shape); });
			std::unordered_map<std::string, RE::NiTransform> byName;
			std::vector<std::pair<RE::NiAVObject*, RE::NiTransform>> placed;
			for (auto* shape : shapes) {
				auto* skin = shape->AsGeometry()->GetGeometryRuntimeData().skinInstance.get();
				auto* data = skin ? skin->skinData.get() : nullptr;
				if (!data || !skin->bones || data->GetBoneCount() == 0) {
					continue;
				}
				const auto count = data->GetBoneCount();
				const auto nameOf = [&](std::uint32_t a_at) { return skin->bones[a_at] ? std::string(skin->bones[a_at]->name.c_str()) : std::string(); };
				// the part's own space, by a bone put already, by the head of the face, or by the first bone it has
				std::optional<RE::NiTransform> space;
				for (std::uint32_t at = 0; at < count && !space; ++at) {
					if (const auto known = byName.find(nameOf(at)); known != byName.end()) {
						space = known->second * data->GetBoneDataSkinToBone(at);
					}
				}
				for (std::uint32_t at = 0; at < count && !space && byName.empty(); ++at) {
					if (nameOf(at).starts_with("NPC Head")) {
						space = skin->bones[at]->world * data->GetBoneDataSkinToBone(at);
					}
				}
				if (!space && byName.empty() && skin->bones[0]) {
					space = skin->bones[0]->world * data->GetBoneDataSkinToBone(0);
				}
				if (!space) {
					shape->SetAppCulled(true);
					continue;
				}
				for (std::uint32_t at = 0; at < count; ++at) {
					auto* bone = skin->bones[at];
					if (!bone || std::ranges::find(placed, bone, &decltype(placed)::value_type::first) != placed.end()) {
						continue;
					}
					const auto world = byName.try_emplace(nameOf(at), *space * data->GetBoneDataSkinToBone(at).Invert()).first->second;
					placed.emplace_back(bone, world);
				}
			}
			// a bone often hangs from another one, the one above is put first so the one below is put from where it ended
			const auto depth = [](const RE::NiAVObject* a_bone) {
				std::size_t above = 0;
				for (const auto* parent = a_bone->parent; parent; parent = parent->parent) {
					above++;
				}
				return above;
			};
			std::ranges::stable_sort(placed, {}, [&](const auto& a_one) { return depth(a_one.first); });
			for (auto& [bone, world] : placed) {
				bone->local = bone->parent ? bone->parent->world.Invert() * world : world;
				bone->world = world;
			}
			a_face.Update(update);
		}

		// what each part of a face is, for the log: a part the portrait leaves out or misplaces shows here
		void TellFace(RE::NiAVObject& a_face, const std::string& a_path)
		{
			ForEachShape(a_face, [&](RE::NiAVObject& a_shape) {
				auto* geometry = a_shape.AsGeometry();
				auto* skin = geometry->GetGeometryRuntimeData().skinInstance.get();
				auto* data = skin ? skin->skinData.get() : nullptr;
				std::string bones;
				for (std::uint32_t at = 0; data && skin->bones && at < data->GetBoneCount() && at < 6; ++at) {
					bones += std::format("{}{}", at ? ", " : "", skin->bones[at] ? skin->bones[at]->name.c_str() : "none");
				}
				auto* lighting = netimmerse_cast<RE::BSLightingShaderProperty*>(geometry->GetGeometryRuntimeData().shaderProperty.get());
				const auto* material = lighting ? static_cast<RE::BSLightingShaderMaterialBase*>(lighting->material) : nullptr;
				const auto& bound = a_shape.worldBound;
				logger::info("face part of {}: {} {}, at {:.0f} {:.0f} {:.0f} r {:.0f}, feature {}, alpha {}, bones [{}]", a_path, a_shape.name.c_str(),
					a_shape.GetAppCulled() ? "hidden" : "shown", bound.center.x, bound.center.y, bound.center.z, bound.radius,
					material ? static_cast<int>(material->GetFeature()) : -1, geometry->GetGeometryRuntimeData().alphaProperty ? "yes" : "no", bones);
			});
		}

		RE::NiMatrix3 FacingCamera(float a_degrees)
		{
			const auto camera = Scene::Camera();
			const auto facing = Scene::Columns(camera.up.Cross(camera.look), camera.look * -1.0F, camera.up);
			return Scene::About(camera.up, a_degrees * std::numbers::pi_v<float> / 180.0F) * facing;
		}

		// a shape gets the textures of the set, the rest of its material stays as the file made it
		void Retexture(RE::BSGeometry& a_shape, RE::BGSTextureSet& a_set)
		{
			auto* lighting = netimmerse_cast<RE::BSLightingShaderProperty*>(a_shape.GetGeometryRuntimeData().shaderProperty.get());
			auto* material = lighting ? static_cast<RE::BSLightingShaderMaterialBase*>(lighting->material) : nullptr;
			auto* dressed = material ? static_cast<RE::BSLightingShaderMaterialBase*>(material->Create()) : nullptr;
			if (!dressed) {
				return;
			}
			dressed->CopyMembers(material);
			dressed->ClearTextures();
			dressed->OnLoadTextureSet(0, &a_set);
			// the property takes its own copy of the material
			lighting->SetMaterial(dressed, true);
			lighting->SetupGeometry(&a_shape);
			lighting->FinishSetupGeometry(&a_shape);
			dressed->~BSLightingShaderMaterialBase();
			RE::free(dressed);
		}

		// The game puts on a face the tint it finds by the record, whatever the face file names. A file made before its
		// plugin was renamed names a tint that isn't there ("RynsWhiterunCityLimits1.2.esp"), the face of the tile came
		// out purple, so the face gets the game's own
		void Retint(RE::NiAVObject& a_face, const RE::TESNPC* a_person)
		{
			const auto tint = a_person ? FaceFile(*a_person, "data\\Textures\\Actors\\Character\\FaceGenData\\FaceTint", "dds") : std::string();
			if (tint.empty()) {
				return;
			}
			ForEachShape(a_face, [&](RE::NiAVObject& a_shape) {
				auto* shape = a_shape.AsGeometry();
				auto* lighting = netimmerse_cast<RE::BSLightingShaderProperty*>(shape->GetGeometryRuntimeData().shaderProperty.get());
				auto* material = lighting ? static_cast<RE::BSLightingShaderMaterialBase*>(lighting->material) : nullptr;
				auto* had = material && material->GetFeature() == RE::BSShaderMaterial::Feature::kFaceGen ? material->textureSet.get() : nullptr;
				const char* named = had ? had->GetTexturePath(RE::BSTextureSet::Texture::kMultilayer) : nullptr;
				// "data\Textures\..." and "textures\..." in any case are one file
				const auto plain = [](std::string_view a_path) {
					std::string path(a_path);
					std::ranges::transform(path, path.begin(), [](unsigned char a_letter) { return static_cast<char>(std::tolower(a_letter == '/' ? '\\' : a_letter)); });
					return path.starts_with("data\\") ? path.substr(5) : path;
				};
				// only a tint the file names elsewhere, a shape of a child's head keeps a wet skin in that slot
				if (!had || !named || plain(named) == plain(tint) || plain(named).find("facegendata\\facetint\\") == std::string::npos) {
					return;
				}
				const RE::NiPointer<RE::BSShaderTextureSet> set{ RE::BSShaderTextureSet::Create() };
				for (std::uint32_t slot = 0; slot < RE::BSTextureSet::Texture::kTotal; ++slot) {
					const auto texture = static_cast<RE::BSTextureSet::Texture>(slot);
					const char* path = had->GetTexturePath(texture);
					set->SetTexturePath(texture, path ? path : "");
				}
				const std::string was = named ? named : "";
				set->SetTexturePath(RE::BSTextureSet::Texture::kMultilayer, tint.c_str());
				auto* dressed = static_cast<RE::BSLightingShaderMaterialBase*>(material->Create());
				if (!dressed) {
					return;
				}
				dressed->CopyMembers(material);
				dressed->ClearTextures();
				dressed->OnLoadTextureSet(0, set.get());
				lighting->SetMaterial(dressed, true);
				lighting->SetupGeometry(shape);
				lighting->FinishSetupGeometry(shape);
				dressed->~BSLightingShaderMaterialBase();
				RE::free(dressed);
				logger::info("face tint of {:08X}: {} in place of {}", a_person->GetFormID(), tint, was.empty() ? "none" : was);
			});
		}

		// A record can put other textures on its model than the file has (alternate textures): cards, coins or potions
		// of one mesh in many looks. The game dresses what it places in the world, the menu's copy gets dressed here,
		// a part by the name the record gives it or by its place among the parts
		void Dress(RE::NiAVObject& a_model, const RE::TESModelTextureSwap* a_swaps)
		{
			if (!a_swaps || !a_swaps->alternateTextures || a_swaps->numAlternateTextures == 0) {
				return;
			}
			std::vector<RE::BSGeometry*> shapes;
			ForEachShape(a_model, [&](RE::NiAVObject& a_shape) { shapes.push_back(a_shape.AsGeometry()); });
			std::string dressed;
			for (std::uint32_t i = 0; i < a_swaps->numAlternateTextures; ++i) {
				const auto& swap = a_swaps->alternateTextures[i];
				if (!swap.textureSet) {
					continue;
				}
				const auto named = std::ranges::find_if(shapes, [&](const RE::BSGeometry* a_shape) { return !swap.name3D.empty() && a_shape->name == swap.name3D; });
				auto* shape = named != shapes.end() ? *named : (swap.index3D < shapes.size() ? shapes[swap.index3D] : nullptr);
				if (shape) {
					Retexture(*shape, *swap.textureSet);
				}
				dressed += std::format("{}{} -> {} ({:08X}{})", dressed.empty() ? "" : ", ", swap.name3D.c_str(), shape ? shape->name.c_str() : "nothing", swap.textureSet->GetFormID(),
					named != shapes.end() ? "" : std::format(", by place {}", swap.index3D));
			}
			logger::info("alternate textures of {}: {}", a_swaps->GetModel(), dressed);
		}

		// Hair that moves with physics often comes as a part of the person's skin, an armor addon of the hair's slots worn
		// under everything, and the hair of the face file stays bare under it. The face gets those parts of the skin
		// that fit the race and cover the hair alone
		void AddSkinHair(RE::NiAVObject& a_face, const RE::TESNPC* a_person)
		{
			auto* holder = a_face.AsNode();
			if (!a_person || !holder) {
				return;
			}
			using Slot = RE::BGSBipedObjectForm::BipedObjectSlot;
			const auto& person = People::TraitsOf(*a_person);
			const auto* race = person.race;
			const auto* skin = person.skin;
			const auto sex = person.GetSex() == RE::SEX::kFemale ? RE::SEXES::kFemale : RE::SEXES::kMale;
			if (!skin) {
				return;
			}
			for (const auto* addon : skin->armorAddons) {
				const bool fits = addon && (addon->race == race || std::ranges::find(addon->additionalRaces, race) != addon->additionalRaces.end());
				const bool ofHair = fits && (addon->HasPartOf(Slot::kHair) || addon->HasPartOf(Slot::kLongHair));
				if (!ofHair || addon->HasPartOf(Slot::kBody)) {
					continue;
				}
				const auto& model = HasFile(addon->bipedModels[sex]) ? addon->bipedModels[sex] : addon->bipedModels[RE::SEXES::kMale];
				IR_BRACKET("hair of the skin {} goes on a face", HasFile(model) ? model.GetModel() : "");
				const auto kept = HasFile(model) ? Kept(model.GetModel()) : nullptr;
				RE::NiPointer<RE::NiAVObject> hair{ kept ? static_cast<RE::NiAVObject*>(kept->Clone()) : nullptr };
				if (!hair) {
					continue;
				}
				Scene::DropCollision(*hair);
				Dress(*hair, &model);
				holder->AttachChild(hair.get(), true);
				logger::info("hair of the skin on the face of {:08X}: {}", a_person->GetFormID(), model.GetModel());
			}
		}

		// A weapon's file often holds its sheath beside it, the part named Scb, and the game's own preview leaves it out
		void DropSheath(RE::NiAVObject& a_model)
		{
			if (auto* sheath = a_model.GetObjectByName("Scb")) {
				sheath->SetAppCulled(true);
			}
		}

		// the menu's own copy of a model the game read, in the textures of its record, turned the way its kind is shown
		RE::NiPointer<RE::NiAVObject> Made(RE::NiNode& a_kept, const File& a_file, bool a_liesFlat, RE::NiMatrix3& a_facing)
		{
			static const auto copying = Profile::Work("tile model copy");
			const Profile::Timer timer{ copying };
			IR_NOTE(timer, "{}", a_file.path);
			IR_BRACKET("the model {} is copied", a_file.path);
			RE::NiPointer<RE::NiAVObject> model{ static_cast<RE::NiAVObject*>(a_kept.Clone()) };
			if (!model) {
				return nullptr;
			}
			Scene::DropCollision(*model);
			Dress(*model, a_file.swaps);
			switch (a_file.kind) {
			case Kind::kFace:
				Retint(*model, a_file.person);
				AddSkinHair(*model, a_file.person);
				PoseFaceBones(*model);
				TellFace(*model, a_file.path);
				a_facing = FacingCamera(kFaceTurnDegrees);
				break;
			case Kind::kBody:
				a_facing = FacingCamera(kCreatureTurnDegrees);
				break;
			default:
				DropSheath(*model);
				a_facing = Facing(*model, a_liesFlat);
			}
			return model;
		}

		// A person shows the face, of the first record of the browser's entry that has one, a creature its body. A
		// person of a race with no face made for it shows nothing, a body with no head would say less than the sign
		// of the kind
		std::vector<File> PortraitFiles(const RE::TESNPC& a_person)
		{
			std::vector<File> files;
			const auto people = People::LookalikesOf(a_person);
			for (std::size_t i = 0; i <= people.size() && i < kFacesTried; ++i) {
				const auto* one = i == 0 ? &a_person : people[i - 1];
				// records of one look share the face file
				if (auto face = FacePath(*one); !face.empty() && std::ranges::find(files, face, &File::path) == files.end()) {
					files.push_back({ std::move(face), Kind::kFace, nullptr, one });
				}
			}
			// people or creatures by most of the records of one name: the first of 83 bandit chiefs takes its looks from
			// a list that starts with a fox, the tile showed a fox
			const auto personRace = [](const RE::TESNPC& a_one) {
				const auto* race = People::RaceOf(a_one);
				return race && std::ranges::any_of(race->GetKeywords(), [](const RE::BGSKeyword* a_keyword) {
					return a_keyword && std::string_view(a_keyword->formEditorID.c_str()) == "ActorTypeNPC";
				});
			};
			std::size_t persons = personRace(a_person) ? 1 : 0;
			for (const auto* one : people) {
				persons += one && one != &a_person && personRace(*one) ? 1 : 0;
			}
			const auto records = 1 + std::ranges::count_if(people, [&](const RE::TESNPC* a_one) { return a_one && a_one != &a_person; });
			const bool creature = !personRace(a_person) && 2 * persons < static_cast<std::size_t>(records);
			if (const auto* body = creature ? BodyModel(a_person) : nullptr; body && HasFile(*body)) {
				files.push_back({ body->GetModel(), Kind::kBody, body });
			}
			return files;
		}

		std::vector<File> FilesOf(RE::TESForm& a_item)
		{
			if (const auto* person = a_item.As<RE::TESNPC>()) {
				return PortraitFiles(*person);
			}
			auto* model = WorldModel(a_item);
			if (!model || !HasFile(*model)) {
				return {};
			}
			return { { model->GetModel(), Kind::kItem, model->GetAsModelTextureSwap() } };
		}

		// zoomDistance is the way the zoom runs, 1 in, -1 out and 0 when it stands, zoomProgress is how far in it is
		bool AtRest(RE::Inventory3DManager& a_preview)
		{
			const auto& zoom = a_preview.GetRuntimeData();
			return zoom.zoomProgress == 0.0F && zoom.zoomDistance == 0.0F;
		}

		void Drop(Shown& a_shown)
		{
			if (!a_shown.model) {
				return;
			}
			Scene::Remove(*a_shown.model);
			if (a_shown.asWorn) {
				Copy::Release(a_shown.model);
			}
			Rest(a_shown.model.get());
			a_shown.model.reset();
		}

		// a worn look measured wrong comes out tiny or off its slot, the log tells what a piece was measured by each time
		// that changes, with the camera's person, slots went small every other open through the tween menu
		std::vector<std::pair<RE::FormID, std::string>> measuresTold;

		void TellWorn(const RE::TESForm& a_item, RE::NiAVObject& a_model)
		{
			const auto* camera = RE::PlayerCamera::GetSingleton();
			const auto reading = std::format("{} person, {}", camera && camera->IsInFirstPerson() ? "first" : "third", Scene::TellMeasure(a_model));
			auto told = std::ranges::find(measuresTold, a_item.GetFormID(), &decltype(measuresTold)::value_type::first);
			if (told != measuresTold.end() && told->second == reading) {
				return;
			}
			if (told == measuresTold.end()) {
				told = measuresTold.insert(measuresTold.end(), { a_item.GetFormID(), {} });
			}
			told->second = reading;
			logger::info("worn look of {:08X} {} in its slot: {}", a_item.GetFormID(), a_item.GetName(), reading);
		}

		void Build(Shown& a_shown)
		{
			auto* form = RE::TESForm::LookupByID(a_shown.slot.item);
			if (!form) {
				IR_LOG("slot {} gets no model, no form {:08X}", a_shown.slot.index, a_shown.slot.item);
				return;
			}
			const auto& slot = a_shown.slot;
			IR_BRACKET("slot {} gets a model of {:08X} {}{}", slot.index, form->GetFormID(), form->GetName(), slot.worn ? ", worn" : "");
			if (slot.worn && Settings::Get().wornLook) {
				if (auto model = WornView::Make(*form)) {
					WornView::Fit(*model, slot.centerX, slot.centerY, slot.size, kWornTurnDegrees);
					TellWorn(*form, *model);
					a_shown.model = model;
					a_shown.asWorn = true;
				} else {
					logger::info("{:08X} {} gave no worn look, its slot shows its own model", form->GetFormID(), form->GetName());
				}
			}
			if (!a_shown.model) {
				static const auto fitting = Profile::Work("tile model fit");
				RE::NiMatrix3 facing;
				if (auto model = Ground(*form, facing)) {
					const Profile::Timer timer{ fitting };
					WornView::FitAround(*model, facing, slot.centerX, slot.centerY, slot.size);
					a_shown.model = model;
					a_shown.asWorn = false;
				}
			}
			if (a_shown.model) {
				Scene::Add(*a_shown.model, Scene::Around(slot.centerX, slot.centerY, slot.size, slot.size));
			}
		}
	}

	RE::NiPointer<RE::NiAVObject> Ground(RE::TESForm& a_item, RE::NiMatrix3& a_facing)
	{
		// the model kept by the game is shared by everything that uses it, the menu gets its own copy
		const auto files = FilesOf(a_item);
		for (const auto& file : files) {
			if (const auto kept = Kept(file.path)) {
				return Made(*kept, file, LiesFlat(a_item), a_facing);
			}
		}
		if (!files.empty() && files.front().kind == Kind::kItem) {
			logger::warn("no model for {:08X} at {}", a_item.GetFormID(), files.front().path);
		}
		return nullptr;
	}

	// The game keeps two places and two sizes for its preview. itemPos and itemScale are where a model rests,
	// itemPosCopy and itemScaleCopy are where it is right now. While the game zooms a model in or out
	// it counts the second pair from the first one every frame, at rest it leaves both alone
	void PlacePreview(float a_centerX, float a_centerY, float a_size, float a_roomHigh, float a_roomWide, float a_growMost, std::optional<Corner> a_corner)
	{
		auto* preview = RE::Inventory3DManager::GetSingleton();
		if (!gamePlace) {
			gamePlace = { preview->itemPos, preview->itemScale };
		}
		const auto place = Scene::Point(a_centerX, a_centerY);
		const float scale = gamePlace->scale * a_size / kPreviewShareAtGameScale;

		if (AtRest(*preview)) {
			// the game reads the place when it puts a model up, a model that's already up has to be moved along
			for (const auto& loaded : preview->GetRuntimeData().loadedModels) {
				if (loaded.spModel) {
					RE::NiUpdateData update;
					loaded.spModel->local.translate += place - preview->itemPos;
					loaded.spModel->Update(update);
				}
			}
			preview->itemPosCopy = place;
			preview->itemScaleCopy = scale;
		}
		preview->itemPos = place;
		preview->itemScale = scale;
		previewRoom = Room{ a_roomWide, a_roomHigh, place, a_growMost, a_corner };
		previewAtHome = false;
	}

	std::optional<std::array<float, 4>> PreviewSeen()
	{
		return previewRoom ? previewSeen : std::nullopt;
	}

	namespace
	{
		// what is seen of a model fills this much of its room, and grows at most this many times the game's size
		constexpr float kFill = 0.92F;
		constexpr float kGrowMost = 3.0F;
		// A long model turns around the line of sight until it lies flat along the room, when it comes out this much bigger
		// so. Only one this many times longer than thick at some turn: boots on their side looked wrong, a sword lying down
		// doesn't. Flat wins over the turn that makes it biggest, a dagger a little aslant in a room with height to spare
		// came out bigger and looked dropped. The turns tried go round half a circle, the other half looks the same
		constexpr float kLayGain = 1.15F;
		constexpr float kLong = 2.0F;
		constexpr std::size_t kTurns = 36;
		// a model something else keeps turning (a preview mod) is no longer measured again, its sphere fits it
		constexpr std::uint32_t kMeasuresMost = 6;
		constexpr float kSameTurn = 0.0001F;

		// what is seen of a model at one turn, at the game's size: how wide and high, and its middle from the model's place
		struct Seen
		{
			float wide = 0.0F;
			float high = 0.0F;
			RE::NiPoint3 middle;
		};

		// The model's size and where its middle goes from the room's middle, in the scene's units right and up
		struct Aside
		{
			float grow;
			float right = 0.0F;
			float up = 0.0F;
		};
		// two ways out of the corner this close in size count as the same
		constexpr float kSameSize = 1.02F;

		// The window's list in the room's top left corner (what the item is made of) never has the model over it. One
		// that would keeps its size and moves right or down out of its way, only as far as it takes, the way that keeps
		// more of its size or else the shorter way. A boot moves a little right, a sword laid along moves a little down.
		// It gets smaller only when neither way has room for it whole
		Aside OutOfCorner(const ItemView::Corner& a_corner, float a_roomWide, float a_roomHigh, const Seen& a_seen, float a_grow)
		{
			const float halfWide = a_roomWide / 2.0F;
			const float halfHigh = a_roomHigh / 2.0F;
			// the corner's right edge and its bottom one from the middle, up is up
			const float edge = Scene::Length(a_corner.right);
			const float floor = -Scene::Length(a_corner.down);
			if (a_seen.wide * a_grow / 2.0F <= -edge || a_seen.high * a_grow / 2.0F <= floor) {
				return { a_grow };
			}
			const float besideWide = halfWide - edge;
			const float underHigh = floor + halfHigh;
			Aside beside{ besideWide > 0.0F ? std::min(a_grow, kFill * std::min(besideWide / a_seen.wide, a_roomHigh / a_seen.high)) : 0.0F };
			beside.right = std::max(0.0F, edge + a_seen.wide * beside.grow / 2.0F);
			Aside under{ underHigh > 0.0F ? std::min(a_grow, kFill * std::min(a_roomWide / a_seen.wide, underHigh / a_seen.high)) : 0.0F };
			under.up = std::min(0.0F, floor - a_seen.high * under.grow / 2.0F);
			// a corner over the whole room leaves the model as it was
			if (beside.grow <= 0.0F && under.grow <= 0.0F) {
				return { a_grow };
			}
			if (beside.grow > under.grow * kSameSize) {
				return beside;
			}
			if (under.grow > beside.grow * kSameSize) {
				return under;
			}
			return beside.right <= -under.up ? beside : under;
		}

		struct Fitted
		{
			const RE::NiAVObject* model;
			std::string name;
			float gameScale;
			RE::NiMatrix3 gameTurn;
			// where it stood as it was measured and the game's place and size of the preview then, to put it back
			RE::NiPoint3 gameTranslate;
			RE::NiPoint3 placeThen;
			float scaleThen = 0.0F;
			std::array<Seen, kTurns> seen;
			// what is seen of it stood up, and the turn in the world that stands it from the game's
			std::optional<Seen> standing;
			RE::NiMatrix3 standTurn;
			bool longOne = false;
			float setScale = 0.0F;
			RE::NiMatrix3 setTurn;
			// the player turns it, the game's preview with the stick of a gamepad: its size and the player's turn stay
			bool turnedByPlayer = false;
			std::uint32_t measures = 0;
			std::size_t told = kTurns;
			// the size and the move out of a corner told last
			std::array<float, 3> toldPlace{};
		};
		std::vector<Fitted> fitted;

		float TurnOf(std::size_t a_step)
		{
			return std::numbers::pi_v<float> * static_cast<float>(a_step) / static_cast<float>(kTurns);
		}

		bool SameTurn(const RE::NiMatrix3& a_one, const RE::NiMatrix3& a_other)
		{
			for (int row = 0; row < 3; ++row) {
				for (int column = 0; column < 3; ++column) {
					if (std::abs(a_one.entry[row][column] - a_other.entry[row][column]) > kSameTurn) {
						return false;
					}
				}
			}
			return true;
		}

		// the world turn a file stands in when its up goes up and its front faces the camera
		RE::NiMatrix3 StandingTurn()
		{
			const auto camera = Scene::Camera();
			return Scene::Columns(camera.right, camera.look, camera.up);
		}

		// Most armor is modelled standing, but the game's preview shows some lying: the ground model of the elven gilded
		// cuirass lies on its back and came as a flat strip. A piece seen this much wider than high that stands taller
		// in its file's own turn, or a quarter turn across the screen, is stood up so. Of the two quarter turns only the
		// one that puts the wider end on top counts, a cuirass's shoulders. A ring or an amulet modelled lying stays as
		// the game shows it, it stands no taller
		constexpr float kLying = 0.6F;
		constexpr float kStandsTaller = 1.5F;

		// what is seen of the points turned so, with how wide its top half and its bottom half are
		Seen SeenAt(const RE::NiMatrix3& a_turn, const std::vector<RE::NiPoint3>& a_points, float& a_topWide, float& a_bottomWide)
		{
			const auto axes = Scene::Camera();
			float left = std::numeric_limits<float>::max(), right = -left, low = left, high = -left;
			for (const auto& point : a_points) {
				const auto turned = a_turn * point;
				left = std::min(left, turned.Dot(axes.right));
				right = std::max(right, turned.Dot(axes.right));
				low = std::min(low, turned.Dot(axes.up));
				high = std::max(high, turned.Dot(axes.up));
			}
			const float middle = (low + high) / 2.0F;
			float topLeft = std::numeric_limits<float>::max(), topRight = -topLeft, bottomLeft = topLeft, bottomRight = -topLeft;
			for (const auto& point : a_points) {
				const auto turned = a_turn * point;
				const float across = turned.Dot(axes.right);
				if (turned.Dot(axes.up) > middle) {
					topLeft = std::min(topLeft, across);
					topRight = std::max(topRight, across);
				} else {
					bottomLeft = std::min(bottomLeft, across);
					bottomRight = std::max(bottomRight, across);
				}
			}
			a_topWide = std::max(0.0F, topRight - topLeft);
			a_bottomWide = std::max(0.0F, bottomRight - bottomLeft);
			return { right - left, high - low, axes.right * ((left + right) / 2.0F) + axes.up * ((low + high) / 2.0F) };
		}

		void FindStanding(Fitted& a_fit, const RE::NiAVObject& a_model, const std::vector<RE::NiPoint3>& a_points)
		{
			constexpr float kQuarter = std::numbers::pi_v<float> / 2.0F;
			const auto axes = Scene::Camera();
			const auto consider = [&](const RE::NiMatrix3& a_turn, bool a_quarter) {
				float top = 0.0F;
				float bottom = 0.0F;
				const auto seen = SeenAt(a_turn, a_points, top, bottom);
				if ((a_quarter && top < bottom) || seen.wide <= 0.0F) {
					return;
				}
				if (!a_fit.standing || seen.high * a_fit.standing->wide > a_fit.standing->high * seen.wide) {
					a_fit.standing = seen;
					a_fit.standTurn = a_turn;
				}
			};
			consider(StandingTurn() * a_model.world.rotate.Transpose(), false);
			consider(Scene::About(axes.right, kQuarter), true);
			consider(Scene::About(axes.right, -kQuarter), true);
		}

		bool StandsUp(const RE::TESForm* a_base, const Fitted& a_fit)
		{
			const auto* armor = a_base ? a_base->As<RE::TESObjectARMO>() : nullptr;
			const auto& game = a_fit.seen[0];
			return armor && !armor->IsShield() && a_fit.standing && game.wide > 0.0F && game.high < game.wide * kLying &&
			       a_fit.standing->high > game.high * kStandsTaller && a_fit.standing->high >= a_fit.standing->wide * kLying;
		}

		Fitted Measured(RE::NiAVObject& a_model, std::uint32_t a_measures)
		{
			Fitted fit{ &a_model, a_model.name.c_str(), a_model.local.scale, a_model.local.rotate };
			const auto* preview = RE::Inventory3DManager::GetSingleton();
			fit.gameTranslate = a_model.local.translate;
			fit.placeThen = preview->itemPos;
			fit.scaleThen = preview->itemScale;
			fit.measures = a_measures + 1;
			fit.setScale = fit.gameScale;
			fit.setTurn = fit.gameTurn;
			const auto axes = Scene::Camera();
			const auto points = fit.measures <= kMeasuresMost ? Scene::Outline(a_model) : std::vector<RE::NiPoint3>{};
			if (points.empty()) {
				// a sphere looks the same whichever way it turns
				const float across = 2.0F * a_model.worldBound.radius;
				const auto middle = a_model.worldBound.center - a_model.world.translate;
				fit.seen.fill({ across, across, axes.right * middle.Dot(axes.right) + axes.up * middle.Dot(axes.up) });
				return fit;
			}
			for (std::size_t step = 0; step < kTurns; ++step) {
				const auto turn = Scene::About(axes.look, TurnOf(step));
				float left = std::numeric_limits<float>::max(), right = -left, low = left, high = -left;
				for (const auto& point : points) {
					const auto turned = turn * point;
					const float across = turned.Dot(axes.right);
					const float along = turned.Dot(axes.up);
					left = std::min(left, across);
					right = std::max(right, across);
					low = std::min(low, along);
					high = std::max(high, along);
				}
				fit.seen[step] = { right - left, high - low, axes.right * ((left + right) / 2.0F) + axes.up * ((low + high) / 2.0F) };
				const float thick = std::min(right - left, high - low);
				fit.longOne = fit.longOne || (thick > 0.0F && std::max(right - left, high - low) >= kLong * thick);
			}
			FindStanding(fit, a_model, points);
			return fit;
		}

		// A spell's art is mostly light, its particles reach far past what shows and measured so it stood as a dot. It
		// keeps the game's own size for the room, the art is made for the game's preview
		bool Spell(const RE::TESForm* a_base)
		{
			return a_base && (a_base->Is(RE::FormType::Spell) || a_base->Is(RE::FormType::Shout));
		}

		// The UI's own card leaves the model at the game's place and size, and the game's preview lays some armor on its
		// back, the elven cuirass lay flat in front of the doll while the window showed it standing. At home it's stood
		// up the same way, about the middle of what is seen of it, so it stays where the game shows it
		void StandAtHome()
		{
			for (const auto& one : RE::Inventory3DManager::GetSingleton()->GetRuntimeData().loadedModels) {
				auto* model = one.spModel.get();
				if (!model || model->GetAppCulled() || Spell(one.itemBase)) {
					continue;
				}
				auto known = std::ranges::find_if(fitted, [&](const Fitted& a_fitted) { return a_fitted.model == model; });
				if (known != fitted.end() && model->local.scale == known->setScale) {
					// turned by the stick of a gamepad, or done already
					if (known->turnedByPlayer || !SameTurn(model->local.rotate, known->setTurn)) {
						known->turnedByPlayer = true;
						known->setTurn = model->local.rotate;
					}
					continue;
				}
				const std::uint32_t measures = known == fitted.end() ? 0 : known->measures;
				if (known != fitted.end()) {
					fitted.erase(known);
				}
				auto& fit = fitted.emplace_back(Measured(*model, measures));
				if (!StandsUp(one.itemBase, fit)) {
					continue;
				}
				auto* parent = model->parent;
				const RE::NiMatrix3 toParent = parent ? parent->world.rotate.Transpose() : RE::NiMatrix3{};
				const RE::NiMatrix3 fromParent = parent ? parent->world.rotate : RE::NiMatrix3{};
				model->local.rotate = toParent * fit.standTurn * fromParent * fit.gameTurn;
				model->local.translate += toParent * (fit.seen[0].middle - fit.standing->middle) / (parent && parent->world.scale > 0.0F ? parent->world.scale : 1.0F);
				RE::NiUpdateData update;
				model->Update(update);
				fit.setTurn = model->local.rotate;
				if (fit.told != kTurns + 1) {
					fit.told = kTurns + 1;
					logger::info("model at the game's place: {} seen {:.1f} x {:.1f}, stood up, {:.1f} x {:.1f}", fit.name, fit.seen[0].wide, fit.seen[0].high, fit.standing->wide,
						fit.standing->high);
				}
			}
		}
	}

	// The game sizes each model for its preview by a rule of its own: a long one (a sword, a staff, a bow) reached past
	// the frame of the item window, a pair of boots stood small in the middle of it. Each model is measured by what is
	// seen of it at the game's size, by its vertices where the renderer keeps them, and made to fill the room the window
	// gives it now both ways. A long one lies along a room wider than high when it comes out bigger so, and what is seen
	// of it goes to the middle of the room. The game keeps its models for the next windows, each window fits them anew.
	// A size or a turn the game sets itself, a zoom, is taken as the game's anew
	void FitPreview()
	{
		auto* preview = RE::Inventory3DManager::GetSingleton();
		const auto& loaded = preview->GetRuntimeData().loadedModels;
		std::erase_if(fitted, [&](const Fitted& a_fitted) {
			return std::ranges::none_of(loaded, [&](const auto& a_loaded) { return a_loaded.spModel.get() == a_fitted.model; });
		});
		if (Inspect::Active() || !AtRest(*preview)) {
			return;
		}
		if (!previewRoom) {
			if (previewAtHome) {
				StandAtHome();
			}
			return;
		}
		const float roomWide = Scene::Length(previewRoom->wide);
		const float roomHigh = Scene::Length(previewRoom->high);
		if (roomWide <= 0.0F || roomHigh <= 0.0F) {
			return;
		}
		const auto axes = Scene::Camera();
		previewSeen.reset();
		for (const auto& one : loaded) {
			auto* model = one.spModel.get();
			if (!model || model->GetAppCulled() || Spell(one.itemBase)) {
				continue;
			}
			auto known = std::ranges::find_if(fitted, [&](const Fitted& a_fitted) { return a_fitted.model == model; });
			// A turn alone, the size still the fitted one, is the player turning the preview with the stick of a gamepad.
			// Measured anew at every turn it changed its size with the outline it showed, and after a few turns fell to the
			// sphere around it and stood smaller. It keeps the size it was fitted to and the player's turn now
			if (known != fitted.end() && model->local.scale == known->setScale && (known->turnedByPlayer || !SameTurn(model->local.rotate, known->setTurn))) {
				known->turnedByPlayer = true;
				known->setTurn = model->local.rotate;
				continue;
			}
			if (known == fitted.end() || model->local.scale != known->setScale || !SameTurn(model->local.rotate, known->setTurn)) {
				const std::uint32_t measures = known == fitted.end() ? 0 : known->measures;
				if (known != fitted.end()) {
					fitted.erase(known);
				}
				fitted.push_back(Measured(*model, measures));
				known = std::prev(fitted.end());
			}
			const auto fits = [&](const Seen& a_seen) {
				return a_seen.wide > 0.0F && a_seen.high > 0.0F ? std::min(roomWide / a_seen.wide, roomHigh / a_seen.high) : 0.0F;
			};
			// Only weapons and ammo lie along the room, the kinds the game itself lays down. A cuirass standing and a
			// potion bottle are long too and were laid on their side. Of turns that lie as flat, the one nearest the
			// game's own wins, so a blade isn't turned over for nothing
			const auto* base = one.itemBase;
			const bool lays = base && (base->Is(RE::FormType::Weapon) || base->Is(RE::FormType::Ammo));
			std::size_t best = 0;
			if (lays && known->longOne && roomWide > roomHigh) {
				const auto nearer = [](std::size_t a_step) { return std::min(a_step, kTurns - a_step); };
				for (std::size_t step = 1; step < kTurns; ++step) {
					const auto& turn = known->seen[step];
					const auto& flattest = known->seen[best];
					if (turn.wide <= 0.0F) {
						continue;
					}
					const float mine = turn.high * flattest.wide;
					const float theirs = flattest.high * turn.wide;
					if (mine < theirs * 0.98F || (mine <= theirs * 1.02F && nearer(step) < nearer(best))) {
						best = step;
					}
				}
				if (fits(known->seen[best]) < fits(known->seen[0]) * kLayGain) {
					best = 0;
				}
			}
			const bool stood = StandsUp(base, *known);
			const auto& seen = stood ? *known->standing : known->seen[best];
			if (fits(seen) <= 0.0F) {
				continue;
			}
			const float fitted = std::min(fits(seen) * kFill, previewRoom->growMost > 0.0F ? previewRoom->growMost : kGrowMost);
			const Aside aside = previewRoom->corner ? OutOfCorner(*previewRoom->corner, roomWide, roomHigh, seen, fitted) : Aside{ fitted };
			const float grow = aside.grow;
			const RE::NiPoint3 target = previewRoom->middle + axes.right * aside.right + axes.up * aside.up;

			// the turn goes around the line of sight, given in the space of the model's parent
			auto* parent = model->parent;
			const RE::NiMatrix3 toParent = parent ? parent->world.rotate.Transpose() : RE::NiMatrix3{};
			const RE::NiMatrix3 fromParent = parent ? parent->world.rotate : RE::NiMatrix3{};
			const RE::NiMatrix3 turn = stood       ? toParent * known->standTurn * fromParent * known->gameTurn :
			                           best == 0   ? known->gameTurn :
			                                         Scene::About(toParent * axes.look, TurnOf(best)) * known->gameTurn;
			const RE::NiPoint3 middle = seen.middle * grow;
			bool moved = false;
			if (model->local.scale != known->gameScale * grow || !SameTurn(model->local.rotate, turn)) {
				model->local.scale = known->gameScale * grow;
				model->local.rotate = turn;
				moved = true;
			}
			// what is seen of it, in the middle of the room or beside the corner
			const RE::NiPoint3 miss = target - (model->world.translate + middle);
			const RE::NiPoint3 shift = axes.right * miss.Dot(axes.right) + axes.up * miss.Dot(axes.up);
			if (shift.Length() > roomHigh * 0.002F) {
				model->local.translate += toParent * shift / (parent && parent->world.scale > 0.0F ? parent->world.scale : 1.0F);
				moved = true;
			}
			if (moved) {
				RE::NiUpdateData update;
				model->Update(update);
			}
			known->setScale = model->local.scale;
			known->setTurn = model->local.rotate;
			const auto from = Scene::Spot(target - axes.right * (seen.wide * grow / 2.0F) + axes.up * (seen.high * grow / 2.0F));
			const auto to = Scene::Spot(target + axes.right * (seen.wide * grow / 2.0F) - axes.up * (seen.high * grow / 2.0F));
			previewSeen = std::array<float, 4>{ from.first, from.second, to.first, to.second };
			const std::size_t picked = stood ? kTurns + 1 : best;
			const std::array<float, 3> place{ grow, aside.right, aside.up };
			if (known->told != picked || known->toldPlace != place) {
				known->told = picked;
				known->toldPlace = place;
				logger::info("model fit: {} seen {:.1f} x {:.1f} at the game's size and turn, room {:.1f} x {:.1f}, {}, {:.2f} times the game's size{}", known->name,
					known->seen[0].wide, known->seen[0].high, roomWide, roomHigh,
					stood ? std::format("stood up, {:.1f} x {:.1f}", seen.wide, seen.high) : std::format("turned {:.0f} degrees", TurnOf(best) * 180.0F / std::numbers::pi_v<float>),
					grow,
					previewRoom->corner ? std::format(", the corner's list to {:.1f} right and {:.1f} down of the middle, {:.2f} of the size the room gives, moved {:.1f} right {:.1f} up",
											  Scene::Length(previewRoom->corner->right), Scene::Length(previewRoom->corner->down), fitted > 0.0F ? grow / fitted : 1.0F, aside.right, aside.up) :
										  std::string());
			}
		}
	}

	std::array<float, 3> GameSpot()
	{
		const auto* preview = RE::Inventory3DManager::GetSingleton();
		const auto [x, y] = Scene::Spot(gamePlace ? gamePlace->position : preview->itemPos);
		return { x, y, kPreviewShareAtGameScale };
	}

	// The models already up go back to the game's own place, size and turn as well: a model the game put up while the
	// place was moved stayed there, an arrow of a chest hung over the screen's top edge after a long card
	void PreviewBack()
	{
		auto* preview = RE::Inventory3DManager::GetSingleton();
		if (gamePlace && AtRest(*preview)) {
			for (const auto& loaded : preview->GetRuntimeData().loadedModels) {
				auto* model = loaded.spModel.get();
				if (!model) {
					continue;
				}
				auto known = std::ranges::find_if(fitted, [&](const Fitted& a_fitted) { return a_fitted.model == model; });
				const bool measured = known != fitted.end();
				const auto from = measured ? known->placeThen : preview->itemPos;
				const float scale = measured ? known->scaleThen : preview->itemScale;
				const auto at = measured ? known->gameTranslate : model->local.translate;
				const float own = measured ? known->gameScale : model->local.scale;
				const float grow = scale > 0.0F ? gamePlace->scale / scale : 1.0F;
				if (measured) {
					model->local.rotate = known->gameTurn;
					fitted.erase(known);
				}
				model->local.translate = gamePlace->position + (at - from) * grow;
				model->local.scale = own * grow;
				RE::NiUpdateData update;
				model->Update(update);
			}
		}
		RestorePreview();
	}

	void RestorePreview()
	{
		previewRoom.reset();
		previewSeen.reset();
		previewAtHome = false;
		if (gamePlace) {
			auto* preview = RE::Inventory3DManager::GetSingleton();
			preview->itemPos = preview->itemPosCopy = gamePlace->position;
			preview->itemScale = preview->itemScaleCopy = gamePlace->scale;
		}
	}

	namespace
	{
		// The doll stands at the depth the game shows an item at, so the model of a row in the game's own place stood
		// inside the doll and its chest covered it. The model comes toward the camera by half the screen's height at
		// that depth and shrinks as much: the same spot and size on the screen, in front of the doll. The doll reaches
		// a quarter of the screen in front of its middle at most (turned, at 140%), a model half its depth behind its
		// own. Half the way at most, closer it gets less of the menu's light (measured 501.5 away, 89.7 high)
		constexpr float kInFrontShare = 0.5F;
		constexpr float kNearestShare = 0.5F;
	}

	void PreviewHome()
	{
		previewRoom.reset();
		previewSeen.reset();
		previewAtHome = true;
		auto* preview = RE::Inventory3DManager::GetSingleton();
		if (!gamePlace) {
			gamePlace = { preview->itemPos, preview->itemScale };
		}
		const auto eye = Scene::Eye();
		const float away = (gamePlace->position - eye).Length();
		const float nearer = away > 0.0F ? std::max(kNearestShare, (away - Scene::Length(kInFrontShare)) / away) : 1.0F;
		const auto place = eye + (gamePlace->position - eye) * nearer;
		const float scale = gamePlace->scale * nearer;
		if (preview->itemPos == place && preview->itemScale == scale) {
			return;
		}
		static std::atomic<bool> told{ false };
		if (!told.exchange(true)) {
			logger::info("the game shows an item {:.1f} from the menu's camera at scale {:.2f}, where the screen is {:.1f} high; its model comes to {:.1f} in front of the doll",
				away, gamePlace->scale, Scene::Length(1.0F), (place - eye).Length());
		}
		// a model already up came at the old place and size, it goes along
		if (AtRest(*preview)) {
			const float grow = preview->itemScale > 0.0F ? scale / preview->itemScale : 1.0F;
			for (const auto& loaded : preview->GetRuntimeData().loadedModels) {
				if (loaded.spModel) {
					RE::NiUpdateData update;
					loaded.spModel->local.translate = eye + (loaded.spModel->local.translate - eye) * (place - eye).Length() / std::max((preview->itemPos - eye).Length(), 1.0F);
					loaded.spModel->local.scale *= grow;
					loaded.spModel->Update(update);
				}
			}
		}
		preview->itemPos = preview->itemPosCopy = place;
		preview->itemScale = preview->itemScaleCopy = scale;
	}

	std::vector<std::int32_t> ShowSlots(const std::vector<Slot>& a_slots)
	{
		// a slot that kept its item and place keeps its model, a worn piece is a whole copy of the body
		std::vector<Shown> next;
		for (const auto& slot : a_slots) {
			auto old = std::ranges::find_if(shown, [&](const Shown& a_old) { return a_old.slot.index == slot.index; });
			const bool same = old != shown.end() && old->model && old->slot.item == slot.item && old->slot.worn == slot.worn && old->slot.centerX == slot.centerX &&
				old->slot.centerY == slot.centerY && old->slot.size == slot.size;
			if (same) {
				next.push_back(std::move(*old));
				shown.erase(old);
				continue;
			}
			Shown fresh{ slot };
			Build(fresh);
			next.push_back(std::move(fresh));
		}
		for (auto& left : shown) {
			Drop(left);
		}
		shown = std::move(next);
		std::vector<std::int32_t> modelled;
		for (const auto& slot : shown) {
			if (slot.model) {
				modelled.push_back(slot.slot.index);
			}
		}
		return modelled;
	}

	RE::NiPointer<RE::NiAVObject> PictureModel(RE::TESForm& a_item, float a_size)
	{
		RE::NiMatrix3 facing;
		auto model = Ground(a_item, facing);
		if (!model) {
			return nullptr;
		}
		RE::NiUpdateData update;
		model->local.translate = {};
		model->local.rotate = facing;
		model->Update(update);
		const auto fit = Measured(*model, 0);
		auto seen = fit.seen[0];
		if (StandsUp(&a_item, fit)) {
			seen = *fit.standing;
			facing = fit.standTurn * facing;
		} else {
			// a long thing lies across its square when that makes it this much bigger, the rest stays as the game turns it
			const auto longest = [&](std::size_t a_step) { return std::max(fit.seen[a_step].wide, fit.seen[a_step].high); };
			std::size_t best = 0;
			for (std::size_t step = 1; step < kTurns; ++step) {
				if (longest(step) < longest(best)) {
					best = step;
				}
			}
			if (longest(0) >= longest(best) * kLayGain) {
				seen = fit.seen[best];
				facing = Scene::About(Scene::Camera().look, TurnOf(best)) * facing;
			}
		}
		const float grow = kFill * Scene::Length(a_size) / std::max({ seen.wide, seen.high, 0.01F });
		model->local.rotate = facing;
		model->local.scale *= grow;
		model->local.translate = Scene::Point(0.5F, 0.5F) - seen.middle * grow;
		model->Update(update);
		return model;
	}

	std::uint32_t PictureOf(const RE::TESForm& a_item)
	{
		const auto files = FilesOf(const_cast<RE::TESForm&>(a_item));
		std::uint32_t hash = 2166136261U;
		for (const char letter : files.empty() ? std::string() : files.front().path) {
			hash = (hash ^ static_cast<std::uint8_t>(std::tolower(static_cast<unsigned char>(letter)))) * 16777619U;
		}
		return hash;
	}

	void Refresh()
	{
		const auto wearer = Subject::Get();
		auto* body = wearer ? wearer->Get3D(false) : nullptr;
		const auto makeup = body ? Copy::Makeup(*body) : 0;
		for (auto& slot : shown) {
			auto* form = RE::TESForm::LookupByID(slot.slot.item);
			if (!form || !slot.slot.worn || slot.asWorn || !Settings::Get().wornLook) {
				continue;
			}
			// a piece that gave nothing to draw on this body isn't copied again until the body changes
			const auto tried = std::pair{ slot.slot.item, makeup };
			if (std::ranges::find(failed, tried) != failed.end()) {
				continue;
			}
			auto model = WornView::Make(*form);
			if (!model) {
				failed.push_back(tried);
				continue;
			}
			Drop(slot);
			WornView::Fit(*model, slot.slot.centerX, slot.slot.centerY, slot.slot.size, kWornTurnDegrees);
			TellWorn(*form, *model);
			slot.model = model;
			slot.asWorn = true;
			Scene::Add(*model, Scene::Around(slot.slot.centerX, slot.slot.centerY, slot.slot.size, slot.slot.size));
		}
	}

	void Clear()
	{
		for (auto& slot : shown) {
			Drop(slot);
		}
		shown.clear();
		failed.clear();
	}

	void WorldFrame()
	{
		if (!resting.empty()) {
			Bury();
		}
	}

	void LetGo(RE::NiPointer<RE::NiAVObject>& a_model)
	{
		Rest(a_model.get());
		a_model.reset();
	}
}
