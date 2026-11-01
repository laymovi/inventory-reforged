#include "PCH.h"

#include "MenuDepth.h"

#include "Settings.h"

#include <d3d11.h>
#include <wrl/client.h>

namespace MenuDepth
{
	namespace
	{
		using Microsoft::WRL::ComPtr;

		// where Community Shaders keeps the depth of the scene for its shaders (Common/SharedData.hlsli, register t17)
		constexpr UINT kDepthSlot = 17;
		// 1.0 as a half float, the far plane in the game's depth
		constexpr std::uint16_t kFarHalf = 0x3C00;

		// kept for the whole game on purpose: a global released when the game quits called into a device already gone
		ComPtr<ID3D11ShaderResourceView>& farView = *new ComPtr<ID3D11ShaderResourceView>();
		UINT madeWidth = 0;
		UINT madeHeight = 0;
		std::uint16_t madePlane = 0;
		bool failed = false;

		// the depth the slot gets. The debug edition can give it the near plane instead, a test that the hair reads the
		// slot during the menu's passes: hair against the near plane is all in shadow
		std::uint16_t Plane()
		{
#if IR_DEBUG_EDITION
			return Settings::Get().menuDepthNear ? std::uint16_t{ 0 } : kFarHalf;
#else
			return kFarHalf;
#endif
		}

		bool CommunityShaders()
		{
			static const bool here = GetModuleHandleW(L"CommunityShaders.dll") != nullptr;
			return here;
		}

		// the formats a depth target is read through by shaders
		bool DepthView(const D3D11_SHADER_RESOURCE_VIEW_DESC& a_view)
		{
			const auto format = a_view.Format;
			return a_view.ViewDimension == D3D11_SRV_DIMENSION_TEXTURE2D &&
			       (format == DXGI_FORMAT_R24_UNORM_X8_TYPELESS || format == DXGI_FORMAT_R32_FLOAT || format == DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS ||
					   format == DXGI_FORMAT_R16_UNORM);
		}

		// A depth all at the far plane of the given size, made once and again when the size changes. Shaders read the
		// slot by pixel, a smaller one would read 0 past its edge, the near plane
		ID3D11ShaderResourceView* FarOfSize(ID3D11Device& a_device, UINT a_width, UINT a_height)
		{
			const auto plane = Plane();
			if (farView && madeWidth == a_width && madeHeight == a_height && madePlane == plane) {
				return farView.Get();
			}
			farView.Reset();
			if (failed || a_width == 0 || a_height == 0) {
				return nullptr;
			}
			D3D11_TEXTURE2D_DESC desc{};
			desc.Width = a_width;
			desc.Height = a_height;
			desc.MipLevels = 1;
			desc.ArraySize = 1;
			desc.Format = DXGI_FORMAT_R16_FLOAT;
			desc.SampleDesc.Count = 1;
			desc.Usage = D3D11_USAGE_IMMUTABLE;
			desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
			const std::vector<std::uint16_t> farPlane(static_cast<std::size_t>(a_width) * a_height, plane);
			const D3D11_SUBRESOURCE_DATA data{ farPlane.data(), a_width * static_cast<UINT>(sizeof(std::uint16_t)), 0 };
			ComPtr<ID3D11Texture2D> texture;
			if (FAILED(a_device.CreateTexture2D(&desc, &data, texture.GetAddressOf())) || FAILED(a_device.CreateShaderResourceView(texture.Get(), nullptr, farView.GetAddressOf()))) {
				logger::warn("no far depth of {}x{} for the menus' 3D, hair there keeps Community Shaders' self shadow", a_width, a_height);
				farView.Reset();
				failed = true;
				return nullptr;
			}
			madeWidth = a_width;
			madeHeight = a_height;
			madePlane = plane;
			logger::info("the menus' 3D gets a {} depth of {}x{} in the slot Community Shaders shades hair against", plane == kFarHalf ? "far" : "near", a_width, a_height);
			return farView.Get();
		}
	}

	Far::Far(bool a_wanted)
	{
		if (!a_wanted || !CommunityShaders()) {
			return;
		}
		auto* renderer = RE::BSGraphics::Renderer::GetSingleton();
		auto* device = renderer ? reinterpret_cast<ID3D11Device*>(renderer->GetRuntimeData().forwarder) : nullptr;
		auto* context = renderer ? reinterpret_cast<ID3D11DeviceContext*>(renderer->GetRuntimeData().context) : nullptr;
		if (!device || !context) {
			return;
		}
		ID3D11ShaderResourceView* current = nullptr;
		context->PSGetShaderResources(kDepthSlot, 1, &current);
		UINT width = 0;
		UINT height = 0;
		if (current) {
			D3D11_SHADER_RESOURCE_VIEW_DESC view{};
			current->GetDesc(&view);
			ComPtr<ID3D11Resource> resource;
			current->GetResource(resource.GetAddressOf());
			ComPtr<ID3D11Texture2D> texture;
			if (!DepthView(view) || !resource || FAILED(resource.As(&texture))) {
				current->Release();
				return;
			}
			D3D11_TEXTURE2D_DESC size{};
			texture->GetDesc(&size);
			width = size.Width;
			height = size.Height;
		} else {
			// nothing bound reads as 0, the near plane, and every ray of the hair would meet it
			const auto screen = RE::BSGraphics::Renderer::GetScreenSize();
			width = screen.width;
			height = screen.height;
		}
		auto* deep = FarOfSize(*device, width, height);
		if (!deep) {
			if (current) {
				current->Release();
			}
			return;
		}
		context->PSSetShaderResources(kDepthSlot, 1, &deep);
		kept = current;
		put = true;
	}

	Far::~Far()
	{
		if (!put) {
			return;
		}
		auto* renderer = RE::BSGraphics::Renderer::GetSingleton();
		if (auto* context = renderer ? reinterpret_cast<ID3D11DeviceContext*>(renderer->GetRuntimeData().context) : nullptr) {
			context->PSSetShaderResources(kDepthSlot, 1, &kept);
		}
		if (kept) {
			kept->Release();
		}
	}
}
