#include "PCH.h"

#include "Station.h"

#include "Settings.h"

namespace Station
{
	namespace
	{
		constexpr auto kCancelScript = "_global.Equipment.panelCancel";

		template <class Menu>
		struct ProcessMessage
		{
			static RE::UI_MESSAGE_RESULTS thunk(Menu* a_menu, RE::UIMessage& a_message)
			{
				const auto* data = a_message.type == RE::UI_MESSAGE_TYPE::kUserEvent ? static_cast<RE::BSUIMessageData*>(a_message.data) : nullptr;
				if (data && Settings::Get().panel && a_menu->uiMovie && data->fixedStr == RE::UserEvents::GetSingleton()->cancel) {
					RE::GFxValue taken;
					IR_SCRIPT(kCancelScript);
					if (a_menu->uiMovie->Invoke(kCancelScript, &taken, nullptr, 0) && taken.IsBool() && taken.GetBool()) {
						return RE::UI_MESSAGE_RESULTS::kHandled;
					}
				}
				return original(a_menu, a_message);
			}

			static void Install()
			{
				constexpr std::size_t kProcessMessage = 4;
				REL::Relocation<std::uintptr_t> table{ Menu::VTABLE[0] };
				original = table.write_vfunc(kProcessMessage, thunk);
			}

			static inline REL::Relocation<decltype(thunk)> original;
		};
	}

	// goes in after ZoomKey::Install, which reads the game's own message handler of the inventory from slot 4
	void Install()
	{
		ProcessMessage<RE::InventoryMenu>::Install();
		ProcessMessage<RE::ContainerMenu>::Install();
		ProcessMessage<RE::BarterMenu>::Install();
		ProcessMessage<RE::MagicMenu>::Install();
		ProcessMessage<RE::CraftingMenu>::Install();
	}
}
