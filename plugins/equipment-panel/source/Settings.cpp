#include "PCH.h"

#include "Settings.h"

#include <cctype>
#include <cmath>

namespace Settings
{
	namespace
	{
		constexpr auto kShipped = "Data/SKSE/Plugins/InventoryReforged.ini";
		constexpr auto kSetInMenu = "Data/MCM/Settings/InventoryReforged.ini";
		// a small ini for each answer of the installer that changes how the mod starts
		constexpr auto kInstalled = "Data/SKSE/Plugins/InventoryReforged";
		// the installer's lines put into the menu's file, so a line the menu changed since is told apart
		constexpr auto kSeeded = "Data/MCM/Settings/InventoryReforged.installed.ini";
		// MCM Helper starts its file with this mark and the system ini reader loses the first section then
		constexpr std::string_view kByteOrderMark = "\xEF\xBB\xBF";
		constexpr std::string_view kBlank = " \t\r";
		// the switch of every slot of the panel in [Slots], in the order the panel numbers the slots
		constexpr std::array kSlotSwitches{ "bShowRight"sv, "bShowLeft"sv, "bShowAmmo"sv, "bShowAmulet"sv, "bShowRing"sv, "bShowHead"sv, "bShowBody"sv,
			"bShowHands"sv, "bShowFeet"sv, "bShowOther"sv };
		// the lines of the item window's numbers in [Numbers] and its small lines in [Lines], in the order the panel
		// numbers them
		constexpr std::array kNumberSwitches{ "bSwing"sv, "bDPS"sv, "bDPM"sv, "bReach"sv, "bStagger"sv, "bCritDamage"sv, "bStops"sv, "bWholeSet"sv,
			"bEffectiveHealth"sv, "bArmorPerWeight"sv };
		constexpr std::array kLineSwitches{ "bKind"sv, "bHave"sv, "bSilver"sv, "bStolen"sv };
		constexpr std::int32_t kLastMadeOf = 2;
		constexpr std::int32_t kLeastScale = 60;
		constexpr std::int32_t kMostScale = 140;
		constexpr std::int32_t kMostShift = 40;
		constexpr std::int32_t kLeastPanel = 60;
		constexpr std::int32_t kFullPanel = 100;
		constexpr std::int32_t kMostPanelShift = 20;
		// [Panel] iPanelWidth of older versions moved the left column in alone: 0 full, 1 narrow, 2 narrower. The same
		// look in width and shift
		constexpr std::array<std::int32_t, 3> kPanelSizeOfWidth{ 100, 88, 76 };
		constexpr std::array<std::int32_t, 3> kPanelShiftOfWidth{ 0, 6, 12 };
		constexpr std::int32_t kLeastWindow = 70;
		constexpr std::int32_t kMostWindow = 160;
		constexpr std::int32_t kLeastText = 80;
		constexpr std::int32_t kMostText = 200;
		constexpr std::int32_t kLeastRowHeight = 100;
		constexpr std::int32_t kMostRowHeight = 200;
		// [Window] iPopUp: 0 at once, 1 after a pause, 2 the UI's own card. Up to 1.5.0 it was iShow, where 2 was "never"
		// (gone now, Details brings the window up in any mode) and builds of 1.5.1 had the UI's own card as 3. A never of
		// then pops up after a pause, the nearest that's left
		constexpr std::int32_t kLastPopUp = 2;
		constexpr std::array<std::int32_t, 4> kPopUpOfShow{ 0, 1, 1, 2 };

		Values current;

		// what a file says, under "section:name"
		using Lines = std::map<std::string, std::string>;

		// what both files say together, the menu reads its values from here. The menu script runs in another thread
		Lines merged;
		std::mutex mergedLock;

		std::string Trimmed(std::string_view a_text)
		{
			const auto first = a_text.find_first_not_of(kBlank);
			const auto last = a_text.find_last_not_of(kBlank);
			return first == std::string_view::npos ? std::string() : std::string(a_text.substr(first, last - first + 1));
		}

		Lines LinesOf(const std::filesystem::path& a_file)
		{
			Lines lines;
			std::ifstream stream(a_file);
			std::string section;
			for (std::string line; std::getline(stream, line);) {
				if (line.starts_with(kByteOrderMark)) {
					line.erase(0, kByteOrderMark.size());
				}
				line = Trimmed(line);
				const auto equals = line.find('=');
				if (line.starts_with('[') && line.ends_with(']')) {
					section = line.substr(1, line.size() - 2);
				} else if (!line.starts_with(';') && equals != std::string::npos) {
					lines[section + ':' + Trimmed(line.substr(0, equals))] = Trimmed(line.substr(equals + 1));
				}
			}
			return lines;
		}

		// a file with iPanelWidth and neither of the two keys that took its place gets them for the same look
		bool PanelOfWidth(Lines& a_lines)
		{
			const auto width = a_lines.find("Panel:iPanelWidth");
			if (width == a_lines.end() || a_lines.contains("Panel:iPanelSize") || a_lines.contains("Panel:iPanelShift")) {
				return false;
			}
			const auto at = static_cast<std::size_t>(std::clamp(std::atoi(width->second.c_str()), 0, static_cast<std::int32_t>(kPanelSizeOfWidth.size()) - 1));
			a_lines["Panel:iPanelSize"] = std::to_string(kPanelSizeOfWidth[at]);
			a_lines["Panel:iPanelShift"] = std::to_string(kPanelShiftOfWidth[at]);
			a_lines.erase(width);
			return true;
		}

		// the lines come sorted as "section:name", so every section is written once with all of its names
		bool Write(const std::filesystem::path& a_file, const Lines& a_lines)
		{
			std::error_code failed;
			std::filesystem::create_directories(a_file.parent_path(), failed);
			std::ofstream stream(a_file, std::ios::trunc);
			std::string section;
			for (const auto& [where, value] : a_lines) {
				const auto at = where.find(':');
				if (where.substr(0, at) != section) {
					section = where.substr(0, at);
					stream << (stream.tellp() > 0 ? "\n[" : "[") << section << "]\n";
				}
				stream << where.substr(at + 1) << " = " << value << '\n';
			}
			return static_cast<bool>(stream);
		}

		// the installer's files in the order of their names
		Lines InstalledLines()
		{
			Lines lines;
			std::vector<std::filesystem::path> files;
			std::error_code failed;
			for (std::filesystem::directory_iterator at(std::filesystem::current_path() / kInstalled, failed), end; !failed && at != end; at.increment(failed)) {
				auto extension = at->path().extension().string();
				std::ranges::transform(extension, extension.begin(), [](unsigned char a_letter) { return static_cast<char>(std::tolower(a_letter)); });
				if (extension == ".ini") {
					files.push_back(at->path());
				}
			}
			std::ranges::sort(files);
			for (const auto& file : files) {
				for (const auto& [key, value] : LinesOf(file)) {
					lines[key] = value;
				}
			}
			PanelOfWidth(lines);
			return lines;
		}

		// MCM Helper shows what the menu's file says, so the installer's answers go into it. A line the menu changed
		// since stays as the player set it, an answer taken back at a new install leaves the file if nobody changed it
		void Seed(const Lines& a_installed, Lines& a_set)
		{
			const auto setFile = std::filesystem::current_path() / kSetInMenu;
			const auto seededFile = std::filesystem::current_path() / kSeeded;
			auto seeded = LinesOf(seededFile);
			bool setChanged = false;
			bool seededChanged = PanelOfWidth(seeded);
			for (const auto& [key, value] : a_installed) {
				const auto had = a_set.find(key);
				const auto put = seeded.find(key);
				if (had != a_set.end() && (put == seeded.end() || had->second != put->second)) {
					continue;
				}
				if (had == a_set.end() || had->second != value) {
					a_set[key] = value;
					setChanged = true;
				}
				if (put == seeded.end() || put->second != value) {
					seeded[key] = value;
					seededChanged = true;
				}
			}
			for (auto put = seeded.begin(); put != seeded.end();) {
				if (a_installed.contains(put->first)) {
					++put;
					continue;
				}
				if (const auto had = a_set.find(put->first); had != a_set.end() && had->second == put->second) {
					a_set.erase(had);
					setChanged = true;
				}
				put = seeded.erase(put);
				seededChanged = true;
			}
			if (setChanged && !Write(setFile, a_set)) {
				logger::warn("the installer's answers couldn't go into {}", kSetInMenu);
			}
			std::error_code failed;
			if (seededChanged && seeded.empty()) {
				std::filesystem::remove(seededFile, failed);
			} else if (seededChanged && !Write(seededFile, seeded)) {
				logger::warn("couldn't write {}", kSeeded);
			}
			if (setChanged || seededChanged) {
				logger::info("the installer's answers: {} lines, {} of them in the menu's file now", a_installed.size(), seeded.size());
			}
		}

		std::string Written(const Lines& a_lines, std::string_view a_section, std::string_view a_name)
		{
			const auto found = a_lines.find(std::string(a_section) + ':' + std::string(a_name));
			return found == a_lines.end() ? std::string() : found->second;
		}

		float Number(const Lines& a_lines, std::string_view a_section, std::string_view a_name, float a_fallback)
		{
			const auto text = Written(a_lines, a_section, a_name);
			char* end = nullptr;
			const float value = std::strtof(text.c_str(), &end);
			// strtof takes "nan" and "inf" too
			return end == text.c_str() || !std::isfinite(value) ? a_fallback : value;
		}

		std::int32_t Whole(const Lines& a_lines, std::string_view a_section, std::string_view a_name, std::int32_t a_fallback, std::int32_t a_least, std::int32_t a_most)
		{
			const float value = Number(a_lines, a_section, a_name, static_cast<float>(a_fallback));
			return std::clamp(static_cast<std::int32_t>(std::lround(value)), a_least, a_most);
		}

		bool Switch(const Lines& a_lines, std::string_view a_section, std::string_view a_name, bool a_fallback)
		{
			const auto text = Written(a_lines, a_section, a_name);
			if (text.empty()) {
				return a_fallback;
			}
			return text == "true" || Number(a_lines, a_section, a_name, 0.0F) != 0.0F;
		}

		// a colour as MCM writes it, a decimal number, or 0xD6B068 typed into the file by hand
		std::uint32_t Color(const Lines& a_lines, std::string_view a_section, std::string_view a_name, std::uint32_t a_fallback)
		{
			const auto text = Written(a_lines, a_section, a_name);
			char* end = nullptr;
			const auto value = std::strtoull(text.c_str(), &end, 0);
			return end == text.c_str() ? a_fallback : static_cast<std::uint32_t>(value & 0xFFFFFF);
		}

		// a file with no iPopUp yet takes it from its iShow, -1 when it has neither
		std::int32_t PopUpOf(const Lines& a_lines)
		{
			if (!Written(a_lines, "Window", "iPopUp").empty()) {
				return Whole(a_lines, "Window", "iPopUp", 0, 0, kLastPopUp);
			}
			if (!Written(a_lines, "Window", "iShow").empty()) {
				return kPopUpOfShow[Whole(a_lines, "Window", "iShow", 0, 0, static_cast<std::int32_t>(kPopUpOfShow.size()) - 1)];
			}
			return -1;
		}

		// [Lines] iMadeOf, or Off for the bMaterial = 0 of the builds before it, -1 when a file has neither
		std::int32_t MadeOfIn(const Lines& a_lines)
		{
			if (!Written(a_lines, "Lines", "iMadeOf").empty()) {
				return Whole(a_lines, "Lines", "iMadeOf", kLastMadeOf, 0, kLastMadeOf);
			}
			if (!Written(a_lines, "Lines", "bMaterial").empty() && !Switch(a_lines, "Lines", "bMaterial", true)) {
				return 0;
			}
			return -1;
		}

		// a switch for each thing of a list, the bit of one switched off is set
		template <std::size_t N>
		std::uint32_t Off(const Lines& a_lines, std::string_view a_section, const std::array<std::string_view, N>& a_switches, std::uint32_t a_fallback)
		{
			std::uint32_t off = a_fallback;
			for (std::uint32_t at = 0; at < N; ++at) {
				const std::uint32_t bit = 1U << at;
				off = Switch(a_lines, a_section, a_switches[at], (off & bit) == 0) ? off & ~bit : off | bit;
			}
			return off;
		}

		void Read(Values& a_values, const Lines& a_lines)
		{
			a_values.panel = Switch(a_lines, "Panel", "bEnabled", a_values.panel);
			a_values.lookButton = Switch(a_lines, "Panel", "bLookButton", a_values.lookButton);
			a_values.stillCamera = Switch(a_lines, "Panel", "bStillCamera", a_values.stillCamera);
			a_values.followers = Switch(a_lines, "Panel", "bFollowers", a_values.followers);
			a_values.keepChoices = Switch(a_lines, "Panel", "bKeepChoices", a_values.keepChoices);
			a_values.companionTabs = Switch(a_lines, "Panel", "bCompanionTabs", a_values.companionTabs);
			a_values.magicMenu = Switch(a_lines, "Panel", "bMagicMenu", a_values.magicMenu);
			a_values.craftingMenu = Switch(a_lines, "Panel", "bCraftingMenu", a_values.craftingMenu);
			a_values.doll = Switch(a_lines, "Doll", "bShow", a_values.doll);
			a_values.pose = static_cast<Pose>(static_cast<std::int32_t>(Number(a_lines, "Doll", "iPose", static_cast<float>(a_values.pose))));
			a_values.turnSpeed = Number(a_lines, "Doll", "fTurnSpeed", a_values.turnSpeed);
			a_values.equipMotion = Switch(a_lines, "Doll", "bEquipMotion", a_values.equipMotion);
			a_values.slotModels = Switch(a_lines, "Slots", "bModels", a_values.slotModels);
			a_values.rowModels = Switch(a_lines, "Slots", "bRowModels", a_values.rowModels);
			a_values.rowHeight = Whole(a_lines, "List", "iRowHeight", a_values.rowHeight, kLeastRowHeight, kMostRowHeight);
			a_values.menuAmbient = Number(a_lines, "Slots", "fMenuAmbient", a_values.menuAmbient);
			a_values.wornLook = Switch(a_lines, "Slots", "bWornLook", a_values.wornLook);
			a_values.hideIcons = Switch(a_lines, "Slots", "bHideIcons", a_values.hideIcons);
			a_values.popup = Switch(a_lines, "Slots", "bPopup", a_values.popup);
			a_values.doubleClickTakesOff = Switch(a_lines, "Slots", "bDoubleClickTakesOff", a_values.doubleClickTakesOff);
			a_values.dragAndDrop = Switch(a_lines, "Slots", "bDragAndDrop", a_values.dragAndDrop);
			a_values.pieceStrips = Switch(a_lines, "Slots", "bPieceStrips", a_values.pieceStrips);
			a_values.arrows = Switch(a_lines, "List", "bArrows", a_values.arrows);
			a_values.equalSign = Switch(a_lines, "List", "bEqualSign", a_values.equalSign);
			a_values.badges = Switch(a_lines, "List", "bBadges", a_values.badges);
			a_values.subcategories = Switch(a_lines, "List", "bSubcategories", a_values.subcategories);
			a_values.lastAdded = Switch(a_lines, "List", "bLastAdded", a_values.lastAdded);
			a_values.stackWeight = Switch(a_lines, "List", "bStackWeight", a_values.stackWeight);
			a_values.rowMenu = Switch(a_lines, "List", "bRowMenu", a_values.rowMenu);
			a_values.stackKey = static_cast<std::int32_t>(Number(a_lines, "List", "iStackKey", static_cast<float>(a_values.stackKey)));
			a_values.newMarks = Switch(a_lines, "List", "bNewMarks", a_values.newMarks);
			a_values.junk = Switch(a_lines, "List", "bJunk", a_values.junk);
			a_values.junkKey = static_cast<std::int32_t>(Number(a_lines, "List", "iJunkKey", static_cast<float>(a_values.junkKey)));
			a_values.weightWarnings = Switch(a_lines, "List", "bWeightWarnings", a_values.weightWarnings);
			a_values.questMarks = Switch(a_lines, "List", "bQuestMarks", a_values.questMarks);
			a_values.stolenApart = Switch(a_lines, "List", "bStolenApart", a_values.stolenApart);
			a_values.dollScale = Whole(a_lines, "Doll", "iScale", a_values.dollScale, kLeastScale, kMostScale);
			a_values.dollRight = Whole(a_lines, "Doll", "iShiftRight", a_values.dollRight, -kMostShift, kMostShift);
			a_values.dollUp = Whole(a_lines, "Doll", "iShiftUp", a_values.dollUp, -kMostShift, kMostShift);
			a_values.panelSize = Whole(a_lines, "Panel", "iPanelSize", a_values.panelSize, kLeastPanel, kFullPanel);
			a_values.panelShift = Whole(a_lines, "Panel", "iPanelShift", a_values.panelShift, -kMostPanelShift, kMostPanelShift);
			a_values.slotsOff = Off(a_lines, "Slots", kSlotSwitches, a_values.slotsOff);
			a_values.numbersOff = Off(a_lines, "Numbers", kNumberSwitches, a_values.numbersOff);
			a_values.linesOff = Off(a_lines, "Lines", kLineSwitches, a_values.linesOff);
			if (const auto madeOf = MadeOfIn(a_lines); madeOf >= 0) {
				a_values.madeOf = static_cast<MadeOf>(madeOf);
			}
			a_values.windowSize = Whole(a_lines, "Window", "iSize", a_values.windowSize, kLeastWindow, kMostWindow);
			if (const auto popUp = PopUpOf(a_lines); popUp >= 0) {
				a_values.windowShow = popUp;
			}
			a_values.nameText = Whole(a_lines, "Window", "iNameText", a_values.nameText, kLeastText, kMostText);
			a_values.wordsText = Whole(a_lines, "Window", "iWordsText", a_values.wordsText, kLeastText, kMostText);
			a_values.numbersText = Whole(a_lines, "Window", "iNumbersText", a_values.numbersText, kLeastText, kMostText);
			a_values.quietText = Whole(a_lines, "Window", "iQuietText", a_values.quietText, kLeastText, kMostText);
			a_values.cardText = Whole(a_lines, "Window", "iCardText", a_values.cardText, kLeastText, kMostText);
			a_values.stats = Switch(a_lines, "Window", "bStats", a_values.stats);
			a_values.heroStats = Switch(a_lines, "Window", "bHeroStats", a_values.heroStats);
			a_values.slotNumbers = Switch(a_lines, "Window", "bSlotNumbers", a_values.slotNumbers);
			a_values.quietTags = Switch(a_lines, "Window", "bQuietTags", a_values.quietTags);
			a_values.modOrigin = Switch(a_lines, "Window", "bModOrigin", a_values.modOrigin);
			a_values.questLine = Switch(a_lines, "Window", "bQuestLine", a_values.questLine);
			a_values.leaveCard = Switch(a_lines, "Window", "bLeaveCard", a_values.leaveCard);
			a_values.inspectOnZoomKey = Switch(a_lines, "Inspect", "bOnZoomKey", a_values.inspectOnZoomKey);
			a_values.accentColor = Color(a_lines, "Look", "iAccentColor", a_values.accentColor);
			a_values.textColor = Color(a_lines, "Look", "iTextColor", a_values.textColor);
			a_values.dumpPose = Switch(a_lines, "Debug", "bDumpPose", a_values.dumpPose);
			a_values.pagesWindow = Switch(a_lines, "Debug", "bPagesWindow", a_values.pagesWindow);
			a_values.dollUnder = Switch(a_lines, "Debug", "bDollUnder", a_values.dollUnder);
			a_values.menuDepth = Switch(a_lines, "Debug", "bMenuDepth", a_values.menuDepth);
			a_values.menuNear = Whole(a_lines, "Debug", "iMenuNear", a_values.menuNear, -1, 1000);
#if IR_DEBUG_EDITION
			a_values.stallSeconds = Whole(a_lines, "Debug", "iStallSeconds", a_values.stallSeconds, 0, 60);
			a_values.menuDepthNear = Switch(a_lines, "Debug", "bMenuDepthNear", a_values.menuDepthNear);
#endif
		}
	}

	void Load()
	{
		Values read;
		auto lines = LinesOf(std::filesystem::current_path() / kShipped);
		PanelOfWidth(lines);
		const auto installed = InstalledLines();
		Lines set;
		{
			// the menu writes the same file from its own thread. Its panel width of an older version goes in under the new
			// names before the installer's answers, so it stays as the player set it
			const std::scoped_lock lock{ mergedLock };
			const auto setFile = std::filesystem::current_path() / kSetInMenu;
			set = LinesOf(setFile);
			if (PanelOfWidth(set)) {
				logger::info("the panel width of an older version is iPanelSize {} and iPanelShift {} now", set["Panel:iPanelSize"], set["Panel:iPanelShift"]);
				if (!Write(setFile, set)) {
					logger::warn("couldn't write {}", kSetInMenu);
				}
			}
			Seed(installed, set);
		}
		// the shipped file, the installer's answers over it and the menu's file over both
		Read(read, lines);
		Read(read, installed);
		Read(read, set);
		current = read;
		for (const auto* layer : std::array<const Lines*, 2>{ &installed, &set }) {
			for (const auto& [key, value] : *layer) {
				lines[key] = value;
			}
		}
		// the menu shows what the file of the menu says, a Pops up set before 1.5.1 goes into it under its new name
		const bool popUpOld = Written(set, "Window", "iPopUp").empty() && !Written(set, "Window", "iShow").empty();
		// and a Material switched off before Made from came stays off there
		const bool madeOfOld = Written(set, "Lines", "iMadeOf").empty() && MadeOfIn(set) == 0;
#if IR_DEBUG_EDITION
		std::string told;
		for (const auto& [key, value] : lines) {
			told += fmt::format("{}{} = {}", told.empty() ? "" : ", ", key, value);
		}
		logger::info("settings, {} of them from the menu's file: {}", set.size(), told);
#endif
		{
			const std::scoped_lock lock{ mergedLock };
			merged = std::move(lines);
		}
		if (popUpOld) {
			logger::info("Pops up of the menu's file, iShow {} of an older version, is iPopUp {} now", Written(set, "Window", "iShow"), read.windowShow);
			Set("iPopUp:Window", static_cast<float>(read.windowShow));
		}
		if (madeOfOld) {
			logger::info("Material switched off in the menu's file, bMaterial of a build before, is Made from Off now");
			Set("iMadeOf:Lines", 0.0F);
		}
	}

	// "bModels:Slots" as the files key it, "Slots:bModels" in the letter case the shipped ini has. A script hands a
	// text over in the case the game met first, so the case of what it asks for doesn't count
	std::string KeyOf(std::string_view a_id)
	{
		const auto colon = a_id.find(':');
		const auto key = std::string(a_id.substr(colon + 1)) + ':' + std::string(a_id.substr(0, colon));
		const auto same = [&](const std::string& a_other) {
			return std::ranges::equal(a_other, key, [](char a_left, char a_right) { return std::tolower(static_cast<unsigned char>(a_left)) == std::tolower(static_cast<unsigned char>(a_right)); });
		};
		for (const auto& [known, value] : merged) {
			if (same(known)) {
				return known;
			}
		}
		return key;
	}

	float Value(std::string_view a_id)
	{
		const std::scoped_lock lock{ mergedLock };
		if (a_id.find(':') == std::string_view::npos) {
			return 0.0F;
		}
		const auto key = KeyOf(a_id);
		const auto colon = key.find(':');
		return Number(merged, key.substr(0, colon), key.substr(colon + 1), 0.0F);
	}

	void Set(std::string_view a_id, float a_value)
	{
		// a script or the menu may hand over nan or inf, casting those to a whole number is undefined
		if (a_id.find(':') == std::string_view::npos || !std::isfinite(a_value)) {
			return;
		}
		const std::scoped_lock lock{ mergedLock };
		const auto key = KeyOf(a_id);
		const auto text = a_value == std::floor(a_value) ? std::to_string(static_cast<std::int64_t>(a_value)) : std::format("{:.4g}", a_value);
		IR_LOG("setting {} goes from {} to {}", key, merged.contains(key) ? merged.at(key) : std::string("nothing"), text);
		const auto file = std::filesystem::current_path() / kSetInMenu;
		auto lines = LinesOf(file);
		lines[key] = text;
		merged[key] = text;
		if (!Write(file, lines)) {
			logger::warn("the menu couldn't write {}", kSetInMenu);
		}
	}

	void Change(std::string_view a_id, float a_value)
	{
		Set(a_id, a_value);
		Values read;
		{
			const std::scoped_lock lock{ mergedLock };
			Read(read, merged);
		}
		current = read;
	}

	const Values& Get()
	{
		return current;
	}

	void Fill(RE::GFxMovie& a_movie, RE::GFxValue& a_object)
	{
		const auto& values = current;
		a_movie.CreateObject(&a_object);
		a_object.SetMember("panel", values.panel);
		a_object.SetMember("lookButton", values.lookButton);
		a_object.SetMember("craftingMenu", values.craftingMenu);
		a_object.SetMember("doll", values.doll);
		a_object.SetMember("turnSpeed", values.turnSpeed);
		a_object.SetMember("slotModels", values.slotModels);
		a_object.SetMember("rowModels", values.rowModels);
		a_object.SetMember("rowHeight", static_cast<double>(values.rowHeight));
		a_object.SetMember("wornLook", values.wornLook);
		a_object.SetMember("hideIcons", values.hideIcons);
		a_object.SetMember("popup", values.popup);
		a_object.SetMember("doubleClickTakesOff", values.doubleClickTakesOff);
		a_object.SetMember("dragAndDrop", values.dragAndDrop);
		a_object.SetMember("pieceStrips", values.pieceStrips);
		a_object.SetMember("arrows", values.arrows);
		a_object.SetMember("equalSign", values.equalSign);
		a_object.SetMember("badges", values.badges);
		a_object.SetMember("subcategories", values.subcategories);
		a_object.SetMember("lastAdded", values.lastAdded);
		a_object.SetMember("stackWeight", values.stackWeight);
		a_object.SetMember("rowMenu", values.rowMenu);
		a_object.SetMember("stackKey", static_cast<double>(values.stackKey));
		a_object.SetMember("newMarks", values.newMarks);
		a_object.SetMember("junk", values.junk);
		a_object.SetMember("junkKey", static_cast<double>(values.junkKey));
		a_object.SetMember("weightWarnings", values.weightWarnings);
		a_object.SetMember("questMarks", values.questMarks);
		a_object.SetMember("dollScale", static_cast<double>(values.dollScale));
		a_object.SetMember("dollRight", static_cast<double>(values.dollRight));
		a_object.SetMember("dollUp", static_cast<double>(values.dollUp));
		a_object.SetMember("slotsOff", static_cast<double>(values.slotsOff));
		a_object.SetMember("numbersOff", static_cast<double>(values.numbersOff));
		a_object.SetMember("linesOff", static_cast<double>(values.linesOff));
		a_object.SetMember("madeOf", static_cast<double>(std::to_underlying(values.madeOf)));
		a_object.SetMember("panelSize", static_cast<double>(values.panelSize));
		a_object.SetMember("panelShift", static_cast<double>(values.panelShift));
		a_object.SetMember("stats", values.stats);
		a_object.SetMember("heroStats", values.heroStats);
		a_object.SetMember("windowSize", static_cast<double>(values.windowSize));
		a_object.SetMember("nameText", static_cast<double>(values.nameText));
		a_object.SetMember("wordsText", static_cast<double>(values.wordsText));
		a_object.SetMember("numbersText", static_cast<double>(values.numbersText));
		a_object.SetMember("quietText", static_cast<double>(values.quietText));
		a_object.SetMember("cardText", static_cast<double>(values.cardText));
		a_object.SetMember("windowShow", static_cast<double>(values.windowShow));
		a_object.SetMember("slotNumbers", values.slotNumbers);
		a_object.SetMember("quietTags", values.quietTags);
		a_object.SetMember("modOrigin", values.modOrigin);
		a_object.SetMember("questLine", values.questLine);
		a_object.SetMember("leaveCard", values.leaveCard);
		a_object.SetMember("inspectOnZoomKey", values.inspectOnZoomKey);
		a_object.SetMember("accent", static_cast<double>(values.accentColor));
		a_object.SetMember("text", static_cast<double>(values.textColor));
	}
}
