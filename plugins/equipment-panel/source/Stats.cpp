#include "PCH.h"

#include "Stats.h"

#include <limits>
#include <unordered_set>

#include "Holders.h"
#include "Settings.h"
#include "Subject.h"
#include "Translations.h"

namespace Stats
{
	namespace
	{
		float Setting(const char* a_name, float a_fallback)
		{
			const auto* setting = RE::GameSettingCollection::GetSingleton()->GetSetting(a_name);
			return setting ? setting->GetFloat() : a_fallback;
		}

		// the game keeps 0 where nothing changed the speed of attacks
		float SpeedMult(RE::Actor& a_actor, RE::ActorValue a_value)
		{
			const float mult = a_actor.AsActorValueOwner()->GetActorValue(a_value);
			return mult > 0.0F ? mult : 1.0F;
		}

		// A pool of health, magicka or stamina: what is left, the most it holds, and how much comes back a second
		// out of a fight. The rate is a share of the most a second, its multiplier a percent on top
		void FillPool(RE::GFxMovie& a_movie, RE::GFxValue& a_object, RE::Actor& a_actor, const char* a_name, RE::ActorValue a_pool, RE::ActorValue a_rate,
			RE::ActorValue a_rateMult, const char* a_combatSetting)
		{
			auto* player = &a_actor;
			auto* values = player->AsActorValueOwner();
			const float most = player->GetActorValueMax(a_pool);
			RE::GFxValue pool;
			a_movie.CreateObject(&pool);
			pool.SetMember("now", values->GetActorValue(a_pool));
			pool.SetMember("most", most);
			pool.SetMember("regen", most * values->GetActorValue(a_rate) / 100.0F * values->GetActorValue(a_rateMult) / 100.0F);
			pool.SetMember("combat", Setting(a_combatSetting, -1.0F));
			a_object.SetMember(a_name, pool);
		}

		// GetWeight gives -1 for arrows in this build of the library, their weight form is found by the game's
		// own type info then
		float WeightOf(RE::TESBoundObject& a_object)
		{
			if (const auto* form = skyrim_cast<RE::TESWeightForm*>(&a_object)) {
				return form->weight;
			}
			return std::max(a_object.GetWeight(), 0.0F);
		}

		// what everything the player wears weighs, the arrows in the quiver as their whole stack
		float WornWeight(RE::Actor& a_player)
		{
			float weight = 0.0F;
			auto* changes = a_player.GetInventoryChanges();
			if (!changes || !changes->entryList) {
				return weight;
			}
			for (auto* entry : *changes->entryList) {
				if (!entry || !entry->object || !entry->extraLists) {
					continue;
				}
				for (auto* extra : *entry->extraLists) {
					if (extra && (extra->HasType(RE::ExtraDataType::kWorn) || extra->HasType(RE::ExtraDataType::kWornLeft))) {
						weight += WeightOf(*entry->object) * static_cast<float>(entry->object->IsAmmo() ? extra->GetCount() : 1);
					}
				}
			}
			return weight;
		}

		struct Skill
		{
			const char* name;
			RE::ActorValue level;
			// what enchantments raise, for a school of magic it's how much cheaper its spells are
			RE::ActorValue modifier;
			// what potions raise, for a school of magic it's how much stronger its spells are
			RE::ActorValue power;
		};

		// In the order of the skills menu. Some effects raise the skill itself, enchantments of heavy and light
		// armor and robes of enchanting do, those show as points over the skill's base
		constexpr std::array kSkills{
			Skill{ "One-handed", RE::ActorValue::kOneHanded, RE::ActorValue::kOneHandedModifier, RE::ActorValue::kOneHandedPowerModifier },
			Skill{ "Two-handed", RE::ActorValue::kTwoHanded, RE::ActorValue::kTwoHandedModifier, RE::ActorValue::kTwoHandedPowerModifier },
			Skill{ "Archery", RE::ActorValue::kArchery, RE::ActorValue::kMarksmanModifier, RE::ActorValue::kMarksmanPowerModifier },
			Skill{ "Block", RE::ActorValue::kBlock, RE::ActorValue::kBlockModifier, RE::ActorValue::kBlockPowerModifier },
			Skill{ "Smithing", RE::ActorValue::kSmithing, RE::ActorValue::kSmithingModifier, RE::ActorValue::kSmithingPowerModifier },
			Skill{ "Heavy armor", RE::ActorValue::kHeavyArmor, RE::ActorValue::kHeavyArmorModifier, RE::ActorValue::kHeavyArmorPowerModifier },
			Skill{ "Light armor", RE::ActorValue::kLightArmor, RE::ActorValue::kLightArmorModifier, RE::ActorValue::kLightArmorPowerModifier },
			Skill{ "Pickpocket", RE::ActorValue::kPickpocket, RE::ActorValue::kPickpocketModifier, RE::ActorValue::kPickpocketPowerModifier },
			Skill{ "Lockpicking", RE::ActorValue::kLockpicking, RE::ActorValue::kLockpickingModifier, RE::ActorValue::kLockpickingPowerModifier },
			Skill{ "Sneak", RE::ActorValue::kSneak, RE::ActorValue::kSneakingModifier, RE::ActorValue::kSneakingPowerModifier },
			Skill{ "Alchemy", RE::ActorValue::kAlchemy, RE::ActorValue::kAlchemyModifier, RE::ActorValue::kAlchemyPowerModifier },
			Skill{ "Speech", RE::ActorValue::kSpeech, RE::ActorValue::kSpeechcraftModifier, RE::ActorValue::kSpeechcraftPowerModifier },
			Skill{ "Alteration", RE::ActorValue::kAlteration, RE::ActorValue::kAlterationModifier, RE::ActorValue::kAlterationPowerModifier },
			Skill{ "Conjuration", RE::ActorValue::kConjuration, RE::ActorValue::kConjurationModifier, RE::ActorValue::kConjurationPowerModifier },
			Skill{ "Destruction", RE::ActorValue::kDestruction, RE::ActorValue::kDestructionModifier, RE::ActorValue::kDestructionPowerModifier },
			Skill{ "Illusion", RE::ActorValue::kIllusion, RE::ActorValue::kIllusionModifier, RE::ActorValue::kIllusionPowerModifier },
			Skill{ "Restoration", RE::ActorValue::kRestoration, RE::ActorValue::kRestorationModifier, RE::ActorValue::kRestorationPowerModifier },
			Skill{ "Enchanting", RE::ActorValue::kEnchanting, RE::ActorValue::kEnchantingModifier, RE::ActorValue::kEnchantingPowerModifier },
		};

		// what the player owes each hold with a bounty, as the game tells it for every faction that
		// keeps track of crime
		void FillBounties(RE::GFxMovie& a_movie, RE::GFxValue& a_object, RE::PlayerCharacter& a_player)
		{
			RE::GFxValue bounties;
			a_movie.CreateArray(&bounties);
			for (const auto* faction : RE::TESDataHandler::GetSingleton()->GetFormArray<RE::TESFaction>()) {
				if (!faction || !faction->TracksCrimes()) {
					continue;
				}
				const auto owed = a_player.GetCrimeGoldValue(faction);
				if (owed > 0) {
					RE::GFxValue one;
					RE::GFxValue name;
					a_movie.CreateObject(&one);
					a_movie.CreateString(&name, faction->GetName());
					one.SetMember("name", name);
					one.SetMember("gold", static_cast<double>(owed));
					bounties.PushBack(one);
				}
			}
			a_object.SetMember("bounties", bounties);
		}

		std::string SpellText(RE::MagicItem& a_spell);

		// the spells in the hands and what a cast costs as the game counts it for the player, a second for a stream
		void FillSpells(RE::GFxMovie& a_movie, RE::GFxValue& a_object, RE::Actor& a_player)
		{
			RE::GFxValue spells;
			a_movie.CreateArray(&spells);
			for (const bool left : { false, true }) {
				auto* form = a_player.GetEquippedObject(left);
				auto* spell = form ? form->As<RE::SpellItem>() : nullptr;
				if (!spell) {
					continue;
				}
				RE::GFxValue one;
				RE::GFxValue name;
				a_movie.CreateObject(&one);
				a_movie.CreateString(&name, spell->GetName());
				one.SetMember("name", name);
				one.SetMember("left", left);
				one.SetMember("cost", spell->CalculateMagickaCost(&a_player));
				one.SetMember("stream", spell->GetCastingType() == RE::MagicSystem::CastingType::kConcentration);
				RE::GFxValue text;
				// the game writes the card's text with the player's perks in it
				a_movie.CreateString(&text, a_player.IsPlayerRef() ? SpellText(*spell).c_str() : "");
				one.SetMember("text", text);
				spells.PushBack(one);
			}
			a_object.SetMember("spells", spells);
		}

		bool RaceSpell(const RE::TESRace* a_race, const RE::MagicItem* a_spell)
		{
			const auto* data = a_race ? a_race->actorEffects : nullptr;
			if (!data || !data->spells) {
				return false;
			}
			for (std::uint32_t i = 0; i < data->numSpells; ++i) {
				if (data->spells[i] == a_spell) {
					return true;
				}
			}
			return false;
		}

		// An effect in the words the game has for it, its strength and time put where the text asks for them
		std::string Worded(std::string text, float a_magnitude, float a_duration)
		{
			const auto put = [&](std::string_view a_tag, const std::string& a_value) {
				for (auto at = text.find(a_tag); at != std::string::npos; at = text.find(a_tag, at + a_value.size())) {
					text.replace(at, a_tag.size(), a_value);
				}
			};
			put("<mag>", std::format("{:.0f}", a_magnitude));
			put("<dur>", std::format("{:.0f}", a_duration));
			// a number in brackets is shown as it is, a global of the game by its value, anything else goes
			constexpr std::string_view kGlobal = "global=";
			for (auto open = text.find('<'); open != std::string::npos; open = text.find('<', open)) {
				const auto close = text.find('>', open);
				if (close == std::string::npos) {
					break;
				}
				const auto inside = text.substr(open + 1, close - open - 1);
				std::string shown;
				if (!inside.empty() && inside.find_first_not_of("0123456789.") == std::string::npos) {
					shown = inside;
				} else if (inside.starts_with(kGlobal)) {
					const auto* global = RE::TESForm::LookupByEditorID<RE::TESGlobal>(inside.substr(kGlobal.size()));
					shown = global ? std::format("{:g}", global->value) : std::string();
				}
				text.replace(open, close - open + 1, shown);
				open += shown.size();
			}
			// the texts of the game end with a line break now and then, a status would stand a line lower
			constexpr std::string_view kSpace = " \t\r\n";
			const auto first = text.find_first_not_of(kSpace);
			return first == std::string::npos ? std::string() : text.substr(first, text.find_last_not_of(kSpace) - first + 1);
		}

		struct Status
		{
			const RE::MagicItem* spell;
			std::string name;
			std::string text;
			float left;
			RE::MagicSystem::SpellType type;
			float magnitude;
			float duration;
		};

		// An ability has no time of its own. Rested and its kin get taken off by a script on the effect that asked
		// for one game-time update some hours on, so that update is when the status ends. Seconds of game time
		float ScriptTimeLeft(RE::ActiveEffect& a_active)
		{
			auto* vm = RE::SkyrimVM::GetSingleton();
			auto* calendar = RE::Calendar::GetSingleton();
			if (!vm || !calendar || !vm->GetVMRuntimeData().impl) {
				return -1.0F;
			}
			auto& data = vm->GetVMRuntimeData();
			const auto* policy = data.impl->GetObjectHandlePolicy();
			const auto handle = policy ? policy->GetHandleForObject(RE::ActiveEffect::VMTYPEID, &a_active) : 0;
			if (!handle || handle == policy->EmptyHandle()) {
				return -1.0F;
			}
			// the queue counts in thousandths of a day
			const float now = calendar->GetDaysPassed() * 1000.0F;
			RE::BSSpinLockGuard guard(data.queuedOnUpdateEventLock);
			for (const auto& update : data.queuedOnUpdateGameEvents) {
				if (update && update->handle == handle && update->updateType == RE::SkyrimVM::UpdateDataEvent::UpdateType::kNoRepeat) {
					return std::max(static_cast<float>(update->timeToSendEvent) - now, 0.0F) / 1000.0F * 24.0F * 3600.0F;
				}
			}
			return -1.0F;
		}

		// What lies on the player now as the Active Effects list shows it, one line a spell: blessings, stones,
		// diseases, potions, spells cast on them. Enchantments of worn gear count into the numbers already, and
		// what the race gives every one of its people says nothing of this player
		void FillStatuses(RE::GFxMovie& a_movie, RE::GFxValue& a_object, RE::Actor& a_player)
		{
			std::vector<Status> found;
			auto* target = a_player.GetMagicTarget();
			auto* effects = target ? target->GetActiveEffectList() : nullptr;
			const auto* race = a_player.GetRace();
			static RE::BSSimpleList<RE::ActiveEffect*> none;
			for (auto* active : effects ? *effects : none) {
				const auto* base = active && active->effect ? active->effect->baseEffect : nullptr;
				if (!base || !active->spell || active->flags.any(RE::ActiveEffect::Flag::kInactive, RE::ActiveEffect::Flag::kDispelled) ||
					base->data.flags.any(RE::EffectSetting::EffectSettingData::Flag::kHideInUI)) {
					continue;
				}
				const auto type = active->spell->GetSpellType();
				if (type == RE::MagicSystem::SpellType::kEnchantment || RaceSpell(race, active->spell)) {
					continue;
				}
				const auto words = Worded(base->magicItemDescription.c_str(), active->magnitude, active->duration);
				const float left = active->duration > 0.0F ? active->duration - active->elapsedSeconds : ScriptTimeLeft(*active);
				auto same = std::ranges::find_if(found, [&](const Status& a_status) { return a_status.spell == active->spell; });
				if (same == found.end()) {
					const char* name = active->spell->GetName();
					found.push_back({ active->spell, name && *name ? name : base->GetName(), words, left, type, active->magnitude, active->duration });
				} else if (!words.empty() && same->text.find(words) == std::string::npos) {
					same->text += same->text.empty() ? words : " " + words;
					same->left = std::max(same->left, left);
				}
			}
			RE::GFxValue statuses;
			a_movie.CreateArray(&statuses);
			for (auto& status : found) {
				// a standing stone and the like keep their words in the spell itself, their effects have none
				if (auto* spell = status.text.empty() ? const_cast<RE::MagicItem*>(status.spell)->As<RE::SpellItem>() : nullptr) {
					RE::BSString told;
					spell->GetDescription(told, spell);
					status.text = Worded(told.c_str() ? told.c_str() : "", status.magnitude, status.duration);
				}
				RE::GFxValue one;
				RE::GFxValue name;
				RE::GFxValue text;
				a_movie.CreateObject(&one);
				a_movie.CreateString(&name, status.name.c_str());
				a_movie.CreateString(&text, status.text.c_str());
				one.SetMember("name", name);
				one.SetMember("text", text);
				one.SetMember("left", status.left);
				one.SetMember("type", static_cast<double>(std::to_underlying(status.type)));
				statuses.PushBack(one);
			}
			a_object.SetMember("statuses", statuses);
		}

		constexpr RE::FormID kUnarmed = 0x1F4;
		// The damage of a weapon with an arrow, the condition of a piece and the text the item card writes for a spell
		// with the player's perks in it. Read from the code of game 1.7.104, the old game's numbers lined up by the
		// callers CommonLib knows on both, PlayerCharacter::GetDamage and the item card's SetItem and SetForm
		constexpr REL::RelocationID kWeaponDamage{ 39215, 40291 };
		constexpr REL::RelocationID kItemCondition{ 15752, 15990 };
		constexpr REL::RelocationID kSpellText{ 51022, 51900 };

		RE::TESObjectWEAP* RightWeapon(RE::Actor& a_player)
		{
			auto* form = a_player.GetEquippedObject(false);
			return form ? form->As<RE::TESObjectWEAP>() : nullptr;
		}

		RE::InventoryEntryData* WornEntry(RE::Actor& a_player, const RE::TESForm* a_object)
		{
			auto* changes = a_player.GetInventoryChanges();
			if (!changes || !changes->entryList) {
				return nullptr;
			}
			for (auto* entry : *changes->entryList) {
				if (entry && entry->object == a_object && entry->IsWorn()) {
					return entry;
				}
			}
			return nullptr;
		}

		// What a sneak attack multiplies a hit by: the game's setting for the kind of weapon, then the perks.
		// Perks that look at the target have none to look at here and stay out, as on the game's item card
		float SneakMult(RE::Actor& a_player, RE::TESObjectWEAP* a_weapon)
		{
			static constexpr std::array kSettings{ "fCombatSneakHandMult", "fCombatSneak1HSwordMult", "fCombatSneak1HDaggerMult", "fCombatSneak1HAxeMult",
				"fCombatSneak1HMaceMult", "fCombatSneak2HSwordMult", "fCombatSneak2HAxeMult", "fCombatSneakBowMult", "fCombatSneakStaffMult", "fCombatSneakCrossbowMult" };
			const auto kind = static_cast<std::size_t>(a_weapon->GetWeaponType());
			float mult = kind < kSettings.size() ? Setting(kSettings[kind], 1.0F) : 1.0F;
			RE::Actor* noTarget = nullptr;
			RE::BGSEntryPoint::HandleEntryPoint(RE::BGSEntryPoint::ENTRY_POINT::kModSneakAttackMult, &a_player, a_weapon, noTarget, &mult);
			return mult;
		}

		// A standing power attack: the stamina it takes, (weight of the weapon times one setting plus another)
		// times the penalty, and what it multiplies the hit by, both from the race's attack data and the perks
		void FillPowerAttack(RE::GFxValue& a_object, RE::Actor& a_player, RE::TESObjectWEAP* a_weapon, bool a_unarmed)
		{
			const RE::BGSAttackData* attack = nullptr;
			if (const auto* race = a_player.GetRace(); race && race->attackDataMap) {
				const auto& known = race->attackDataMap->attackDataMap;
				if (const auto found = known.find(RE::BSFixedString("attackPowerStartInPlace")); found != known.end()) {
					attack = found->second.get();
				}
			}
			const float weight = a_unarmed ? 1.0F : a_weapon->GetWeight();
			float stamina = (weight * Setting("fStaminaAttackWeaponMult", 0.0F) + Setting("fStaminaAttackWeaponBase", 0.0F)) * Setting("fPowerAttackStaminaPenalty", 1.0F);
			RE::BGSEntryPoint::HandleEntryPoint(RE::BGSEntryPoint::ENTRY_POINT::kModPowerAttackStamina, &a_player, a_weapon, &stamina);
			stamina *= attack ? attack->data.staminaMult : 1.0F;
			float damage = attack ? attack->data.damageMult : 1.0F;
			RE::Actor* noTarget = nullptr;
			RE::BGSEntryPoint::HandleEntryPoint(RE::BGSEntryPoint::ENTRY_POINT::kModPowerAttackDamage, &a_player, a_weapon, noTarget, &damage);
			a_object.SetMember("powerStamina", stamina);
			a_object.SetMember("powerDamage", damage);
		}

		// A bow with the arrow nocked as the game puts the shot together, the arrow before the skill and the perks,
		// brought to the scale of the damage the menu shows for the bow alone
		void FillBowDamage(RE::GFxMovie& a_movie, RE::GFxValue& a_object, RE::PlayerCharacter& a_player, RE::TESObjectWEAP* a_bow)
		{
			auto* arrow = a_player.GetCurrentAmmo();
			auto* entry = WornEntry(a_player, a_bow);
			if (!arrow || !entry) {
				return;
			}
			const REL::Relocation<float(RE::InventoryEntryData*)> condition{ kItemCondition };
			const REL::Relocation<float(RE::Actor*, RE::TESObjectWEAP*, RE::TESAmmo*, float)> damage{ kWeaponDamage };
			const float kept = condition(entry);
			const float alone = damage(&a_player, a_bow, nullptr, kept);
			if (alone <= 0.0F) {
				return;
			}
			RE::GFxValue name;
			a_movie.CreateString(&name, arrow->GetName());
			a_object.SetMember("arrow", name);
			a_object.SetMember("bowDamage", damage(&a_player, a_bow, arrow, kept) * a_player.GetDamage(entry) / alone);
		}

		// what a sneak attack, a power attack and a shot of the bow do with the weapon in the right hand, fists without one
		void FillCombat(RE::GFxMovie& a_movie, RE::GFxValue& a_object, RE::Actor& a_player)
		{
			// a spell in the right hand swings nothing
			if (const auto* held = a_player.GetEquippedObject(false); held && !held->Is(RE::FormType::Weapon)) {
				return;
			}
			auto* weapon = RightWeapon(a_player);
			const bool unarmed = !weapon;
			if (unarmed) {
				weapon = RE::TESForm::LookupByID<RE::TESObjectWEAP>(kUnarmed);
			}
			if (!weapon || weapon->IsStaff()) {
				return;
			}
			a_object.SetMember("sneakMult", SneakMult(a_player, weapon));
			if (!weapon->IsBow() && !weapon->IsCrossbow()) {
				FillPowerAttack(a_object, a_player, weapon, unarmed);
			} else {
				// the bow's damage the menu shows is counted for the player
				if (a_player.IsPlayerRef()) {
					FillBowDamage(a_movie, a_object, static_cast<RE::PlayerCharacter&>(a_player), weapon);
				}
			}
		}

		// the text the item card writes for a spell, numbers with the player's perks, the tags of its font left out
		std::string SpellText(RE::MagicItem& a_spell)
		{
			const REL::Relocation<void(void*, RE::MagicItem*, RE::BSString*)> write{ kSpellText };
			RE::BSString written;
			write(nullptr, &a_spell, &written);
			std::string text = written.c_str() ? written.c_str() : "";
			for (auto open = text.find('<'); open != std::string::npos; open = text.find('<', open)) {
				const auto close = text.find('>', open);
				if (close == std::string::npos) {
					break;
				}
				text.erase(open, close - open + 1);
			}
			return text;
		}

		void FillSkills(RE::GFxMovie& a_movie, RE::GFxValue& a_object, RE::ActorValueOwner& a_values)
		{
			RE::GFxValue skills;
			a_movie.CreateArray(&skills);
			for (const auto& skill : kSkills) {
				RE::GFxValue one;
				a_movie.CreateObject(&one);
				one.SetMember("name", skill.name);
				// the name the skills menu shows, in the language of the game
				if (const auto* info = RE::ActorValueList::GetActorValueInfo(skill.level); info && info->GetFullName() && *info->GetFullName()) {
					RE::GFxValue shown;
					a_movie.CreateString(&shown, info->GetFullName());
					one.SetMember("shown", shown);
				}
				one.SetMember("points", a_values.GetActorValue(skill.level) - a_values.GetBaseActorValue(skill.level));
				one.SetMember("modifier", a_values.GetActorValue(skill.modifier));
				one.SetMember("power", a_values.GetActorValue(skill.power));
				skills.PushBack(one);
			}
			a_object.SetMember("skills", skills);
		}

		// a name as the game gives it in its language, a mod's "$Key" through the translation files
		std::string NameOf(const RE::TESForm& a_form)
		{
			const char* named = a_form.GetName();
			std::string name = named ? named : "";
			if (name.starts_with('$')) {
				if (auto words = Translations::Game(name); !words.empty()) {
					return words;
				}
			}
			return name;
		}

		// The corner shows this many parts of a recipe and counts the rest, a recipe of the game takes a handful. A name is
		// cut to this many bytes (the corner cuts any name to its column long before), a count to what an int holds
		constexpr std::size_t kPartsMost = 32;
		constexpr std::size_t kNameMost = 200;
		constexpr std::int64_t kCountMost = std::numeric_limits<std::int32_t>::max();

		// A name for one line of the corner: line breaks, tabs and other control letters of a broken record become spaces,
		// a name past kNameMost is cut where no letter of UTF-8 breaks and gets "..."
		std::string OneLine(std::string a_name)
		{
			for (auto& letter : a_name) {
				if (static_cast<unsigned char>(letter) < 0x20 || letter == 0x7F) {
					letter = ' ';
				}
			}
			const auto first = a_name.find_first_not_of(' ');
			if (first == std::string::npos) {
				return {};
			}
			a_name = a_name.substr(first, a_name.find_last_not_of(' ') - first + 1);
			if (a_name.size() > kNameMost) {
				std::size_t cut = kNameMost;
				while (cut > 0 && (static_cast<unsigned char>(a_name[cut]) & 0xC0) == 0x80) {
					--cut;
				}
				a_name = a_name.substr(0, cut) + "...";
			}
			return a_name;
		}

		// What the recipe that makes the item takes, each thing once with how many, for the corner of the item window.
		// Only while the window lists them ([Lines] iMadeOf 2), the recipe is a find in the index of the records. Mod
		// recipes can be broken: a part that's gone, a count of 0 or less, one thing listed many times or a hundred
		// things. The first kPartsMost go to the corner, madeOfMore counts the other things
		void FillMadeOf(RE::GFxMovie& a_movie, RE::GFxValue& a_object, const RE::TESForm& a_item)
		{
			const auto* recipe = Settings::Get().madeOf == Settings::MadeOf::kComponents ? Holders::MadeBy(a_item) : nullptr;
			if (!recipe) {
				return;
			}
			std::vector<std::pair<const RE::TESForm*, std::int64_t>> parts;
			// made only for a recipe past kPartsMost, the hover of a sane one allocates nothing more
			std::optional<std::unordered_set<const RE::TESForm*>> more;
			for (const auto* entry : Holders::Parts(*recipe)) {
				const RE::TESForm* part = entry ? entry->obj : nullptr;
				if (!Holders::Named(part) || entry->count <= 0) {
					continue;
				}
				if (const auto same = std::ranges::find(parts, part, &decltype(parts)::value_type::first); same != parts.end()) {
					same->second = std::min(same->second + entry->count, kCountMost);
				} else if (parts.size() < kPartsMost) {
					parts.emplace_back(part, entry->count);
				} else {
					(more ? *more : more.emplace()).insert(part);
				}
			}
			RE::GFxValue made;
			a_movie.CreateArray(&made);
			for (const auto& [part, count] : parts) {
				const auto shown = OneLine(NameOf(*part));
				if (shown.empty()) {
					continue;
				}
				RE::GFxValue one;
				RE::GFxValue name;
				a_movie.CreateObject(&one);
				a_movie.CreateString(&name, shown.c_str());
				one.SetMember("name", name);
				one.SetMember("count", static_cast<double>(count));
				made.PushBack(one);
			}
			a_object.SetMember("madeOf", made);
			if (more) {
				a_object.SetMember("madeOfMore", static_cast<double>(more->size()));
			}
		}
	}

	void FillHero(RE::GFxMovie& a_movie, RE::GFxValue& a_object, RE::Actor& a_actor)
	{
		auto* player = &a_actor;
		auto* values = player->AsActorValueOwner();
		auto* own = player->IsPlayerRef() ? static_cast<RE::PlayerCharacter*>(player) : nullptr;
		a_movie.CreateObject(&a_object);
		FillPool(a_movie, a_object, a_actor, "health", RE::ActorValue::kHealth, RE::ActorValue::kHealRate, RE::ActorValue::kHealRateMult, "fCombatHealthRegenRateMult");
		FillPool(a_movie, a_object, a_actor, "magicka", RE::ActorValue::kMagicka, RE::ActorValue::kMagickaRate, RE::ActorValue::kMagickaRateMult, "fCombatMagickaRegenRateMult");
		FillPool(a_movie, a_object, a_actor, "stamina", RE::ActorValue::kStamina, RE::ActorValue::kStaminaRate, RE::ActorValue::kStaminaRateMult, "fCombatStaminaRegenRateMult");
		a_object.SetMember("armorScale", Setting("fArmorScalingFactor", 0.12F));
		a_object.SetMember("armorBase", Setting("fArmorBaseFactor", 0.03F));
		a_object.SetMember("armorCap", Setting("fMaxArmorRating", 80.0F));
		a_object.SetMember("resistCap", Setting("fPlayerMaxResistance", 85.0F));
		constexpr std::array kResists{
			std::pair{ "magic", RE::ActorValue::kResistMagic },
			std::pair{ "fire", RE::ActorValue::kResistFire },
			std::pair{ "frost", RE::ActorValue::kResistFrost },
			std::pair{ "shock", RE::ActorValue::kResistShock },
			std::pair{ "poison", RE::ActorValue::kPoisonResist },
			std::pair{ "disease", RE::ActorValue::kResistDisease },
		};
		for (const auto& [name, value] : kResists) {
			a_object.SetMember(name, values->GetActorValue(value));
		}
		a_object.SetMember("speedMult", SpeedMult(a_actor, RE::ActorValue::kWeaponSpeedMult));
		a_object.SetMember("leftSpeedMult", SpeedMult(a_actor, RE::ActorValue::kLeftWeaponSpeedMultiply));
		a_object.SetMember("crit", values->GetActorValue(RE::ActorValue::kCriticalChance));
		a_object.SetMember("unarmed", values->GetActorValue(RE::ActorValue::kUnarmedDamage));
		a_object.SetMember("move", values->GetActorValue(RE::ActorValue::kSpeedMult));
		a_object.SetMember("worn", WornWeight(*player));
		a_object.SetMember("carried", player->GetWeightInContainer());
		a_object.SetMember("most", player->GetTotalCarryWeight());
		// the weight the game slows the player by, perks like Conditioning take heavy armor out of it
		a_object.SetMember("wornForSpeed", player->GetEquippedWeight());
		a_object.SetMember("noise", values->GetActorValue(RE::ActorValue::kMovementNoiseMult));
		a_object.SetMember("shout", values->GetActorValue(RE::ActorValue::kShoutRecoveryMult));
		a_object.SetMember("absorb", values->GetActorValue(RE::ActorValue::kAbsorbChance));
		a_object.SetMember("reflect", values->GetActorValue(RE::ActorValue::kReflectDamage));
		a_object.SetMember("waterBreathing", values->GetActorValue(RE::ActorValue::kWaterBreathing));
		FillSkills(a_movie, a_object, *values);
		// a bounty and the way to the next level are the player's alone
		if (own) {
			FillBounties(a_movie, a_object, *own);
		}
		FillSpells(a_movie, a_object, *player);
		FillStatuses(a_movie, a_object, *player);
		FillCombat(a_movie, a_object, *player);
		a_object.SetMember("walkSpeed", player->GetWalkSpeed());
		a_object.SetMember("runSpeed", player->GetRunSpeed());
		// the shout in hand with how long each of its words rests the voice, learned are the words known and
		// opened with a soul, and how long the voice still rests now
		const auto* power = player->GetActorRuntimeData().selectedPower;
		if (const auto* shout = power ? power->As<RE::TESShout>() : nullptr) {
			RE::GFxValue voice;
			RE::GFxValue words;
			a_movie.CreateObject(&voice);
			a_movie.CreateArray(&words);
			voice.SetMember("name", shout->GetName());
			for (const auto& variation : shout->variations) {
				RE::GFxValue word;
				a_movie.CreateObject(&word);
				word.SetMember("seconds", variation.recoveryTime);
				word.SetMember("learned", variation.word && variation.word->GetKnown() && (variation.word->formFlags & RE::TESForm::RecordFlags::kUnlocked) != 0);
				words.PushBack(word);
			}
			voice.SetMember("words", words);
			a_object.SetMember("voice", voice);
		}
		a_object.SetMember("voiceWait", player->GetVoiceRecoveryTime());
		a_object.SetMember("level", static_cast<double>(player->GetLevel()));
		const auto* skills = own ? own->GetInfoRuntimeData().skills : nullptr;
		if (skills && skills->data && skills->data->levelThreshold > 0.0F) {
			a_object.SetMember("toNextLevel", skills->data->xp / skills->data->levelThreshold);
		}
	}

	void Fill(RE::GFxMovie& a_movie, RE::GFxValue& a_object, RE::FormID a_item)
	{
		a_movie.CreateObject(&a_object);
		a_object.SetMember("armorScale", Setting("fArmorScalingFactor", 0.12F));
		// each worn piece of light or heavy armor stops a share of its own on top, it's what makes the 567 cap
		a_object.SetMember("armorBase", Setting("fArmorBaseFactor", 0.03F));
		a_object.SetMember("armorCap", Setting("fMaxArmorRating", 80.0F));
		auto* form = RE::TESForm::LookupByID(a_item);
		if (auto* weapon = form ? form->As<RE::TESObjectWEAP>() : nullptr) {
			a_object.SetMember("kind", "weapon");
			a_object.SetMember("type", static_cast<double>(static_cast<std::uint32_t>(weapon->GetWeaponType())));
			a_object.SetMember("speed", weapon->GetSpeed());
			a_object.SetMember("reach", weapon->GetReach());
			a_object.SetMember("stagger", weapon->weaponData.staggerValue);
			a_object.SetMember("critDamage", static_cast<double>(weapon->criticalData.damage));
			a_object.SetMember("critMult", weapon->criticalData.prcntMult);
			if (const auto shown = Subject::Get()) {
				a_object.SetMember("speedMult", SpeedMult(*shown, RE::ActorValue::kWeaponSpeedMult));
				a_object.SetMember("leftSpeedMult", SpeedMult(*shown, RE::ActorValue::kLeftWeaponSpeedMultiply));
			}
		} else if (auto* armor = form ? form->As<RE::TESObjectARMO>() : nullptr) {
			a_object.SetMember("kind", "armor");
			a_object.SetMember("rating", armor->GetArmorRating());
		}
		if (form) {
			FillMadeOf(a_movie, a_object, *form);
		}
	}
}

namespace Stats
{
	std::string Words(std::string a_text, float a_magnitude, float a_duration)
	{
		return Worded(std::move(a_text), a_magnitude, a_duration);
	}

	// Every piece made on a plain one (a TNAM, a weapon's CNAM) asked as the window asks, so a log of any game says the
	// enchanted ones find the plain one's recipe, and how many templates of broken plugins loop back. A pass over the
	// armor and weapons once after the data loads, a hash find or a few per piece. A part a mod names by a "$Key" has
	// the translation files of every plugin read here, on the loading thread, so the first window that shows one
	// doesn't wait on them
	void TellMadeOf()
	{
		const auto start = std::chrono::steady_clock::now();
		const auto& own = Holders::Read().madeBy;
		std::size_t templated = 0;
		std::size_t mine = 0;
		std::size_t byPlain = 0;
		std::size_t looped = 0;
		std::string first;
		const auto count = [&](const RE::TESForm& a_item) {
			const auto* plain = Holders::TemplateOf(a_item);
			if (!plain) {
				return;
			}
			++templated;
			// a piece on itself or on a piece on it, a longer loop is left to MadeBy's cap
			const auto* step = plain;
			for (std::size_t i = 0; step && i < 4 && step != &a_item; ++i) {
				step = Holders::TemplateOf(*step);
			}
			looped += step == &a_item ? 1 : 0;
			if (own.contains(&a_item)) {
				++mine;
				return;
			}
			const auto* recipe = Holders::MadeBy(a_item);
			if (!recipe) {
				return;
			}
			++byPlain;
			if (!first.empty()) {
				return;
			}
			first = std::format("{} {:08X} by {} {:08X}:", OneLine(NameOf(a_item)), a_item.GetFormID(), OneLine(NameOf(*plain)), plain->GetFormID());
			for (const auto* entry : Holders::Parts(*recipe)) {
				if (entry && Holders::Named(entry->obj)) {
					first += std::format(" {} x{}", OneLine(NameOf(*entry->obj)), entry->count);
				}
			}
		};
		auto* data = RE::TESDataHandler::GetSingleton();
		for (const auto* armor : data->GetFormArray<RE::TESObjectARMO>()) {
			if (armor) {
				count(*armor);
			}
		}
		for (const auto* weapon : data->GetFormArray<RE::TESObjectWEAP>()) {
			if (weapon) {
				count(*weapon);
			}
		}
		const auto counted = std::chrono::steady_clock::now();
		const RE::TESForm* keyed = nullptr;
		for (auto at = own.begin(); at != own.end() && !keyed; ++at) {
			for (const auto* entry : Holders::Parts(*at->second)) {
				const char* name = entry && entry->obj ? entry->obj->GetName() : nullptr;
				if (name && *name == '$') {
					keyed = entry->obj;
					break;
				}
			}
		}
		if (keyed) {
			NameOf(*keyed);
		}
		const auto took = [](auto a_from, auto a_to) { return std::chrono::duration<double, std::milli>(a_to - a_from).count(); };
		logger::info("what items are made of: {} items have a recipe that makes them, {} of {} pieces made on a plain one find its recipe, {} have their own, "
					 "{} templates loop back; the first {}; {:.1f} ms{}",
			own.size(), byPlain, templated, mine, looped, first.empty() ? "none" : first, took(start, counted),
			keyed ? std::format(", the words of a part named {:08X} {} read in {:.1f} ms", keyed->GetFormID(), OneLine(keyed->GetName()), took(counted, std::chrono::steady_clock::now())) : std::string());
	}
}
