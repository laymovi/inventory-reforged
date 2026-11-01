#include "PCH.h"

#include "ItemPictures.h"

#include "ItemView.h"
#include "Profile.h"
#include "Scene.h"
#include "Settings.h"
#include "Translations.h"

#ifndef NOMINMAX
#	define NOMINMAX
#endif
#include <Windows.h>
#include <d3d11_1.h>
#include <deque>
#include <wrl/client.h>

namespace ItemPictures
{
	namespace
	{
		using Microsoft::WRL::ComPtr;

		constexpr std::uint32_t kDrawn = 288;
		// the share of the picture a model may take, the rest is air between it and the edge of its square
		constexpr float kRoom = 0.84F;
		// goes up when pictures should look different, the old files are left and new ones made
		constexpr int kLook = 10;
		constexpr std::uint32_t kKept = 72;
		constexpr std::uint32_t kShrink = kDrawn / kKept;
		// one pixel of 72 is half of one of a row at 1080
		constexpr int kOutline = 1;
		constexpr float kOutlineStrength = 0.85F;
		constexpr std::array<std::uint8_t, 3> kOutlineColor{ 14, 16, 20 };
		constexpr float kBrightness = 0.45F;
		constexpr float kGainLeast = 0.7F;
		constexpr float kGainMost = 2.5F;
		// textures stream in after the model, one that never comes doesn't hold the rest up
		constexpr auto kTexturesWaitLeast = std::chrono::milliseconds(150);
		constexpr auto kTexturesWaitMost = std::chrono::seconds(3);
		constexpr float kAmbientToTellCover = 100.0F;
		constexpr std::uint8_t kNoCover = 1;
		constexpr const char* kFolder = "Textures\\InventoryReforged\\Items";
		constexpr std::size_t kPluginInName = 64;
		constexpr const char* kTryingFile = "Trying.txt";
		constexpr const char* kSkippedFile = "Skipped.txt";
		// what Write makes is always this long, signature, IHDR, IDAT with its one stored block, IEND
		constexpr std::uintmax_t kFileBytes = 8 + (12 + 13) + (12 + 2 + 5 + (kKept * 4 + 1) * kKept + 4) + 12;

		struct Drawing
		{
			RE::FormID item = 0;
			std::string name;
			RE::NiPointer<RE::NiAVObject> model;
			std::chrono::steady_clock::time_point since;
		};

		std::vector<RE::FormID> wanted;
		std::unordered_map<RE::FormID, std::string> urls;
		// nothing to draw of these, no model or no file to name it by
		std::unordered_set<RE::FormID> without;
		// these four are never freed, as the game quits they'd reach a scene graph and movies already gone
		auto& drawing = *new std::optional<Drawing>();
		bool broken = false;

		std::string FileName(const RE::TESForm& a_item)
		{
			const auto* file = a_item.GetFile(0);
			// a thing made in play, a brewed potion, has no plugin and its number differs from save to save, its model names it
			if (!file || a_item.IsDynamicForm()) {
				return std::format("Made_{:08X}_{}.png", ItemView::PictureOf(a_item), kLook);
			}
			// an address with a space in it is no address to Flash
			std::string plugin{ file->GetFilename() };
			std::ranges::replace_if(plugin, [](unsigned char a_letter) { return !std::isalnum(a_letter); }, '_');
			// The game walks all of Data as it starts and aborts on a full path of 260, one picture of a plugin with a long
			// name and it wouldn't start any more. A long name gets cut and keeps a hash to stay its own
			if (plugin.size() > kPluginInName) {
				const auto whole = static_cast<std::uint32_t>(std::hash<std::string>{}(plugin));
				plugin = std::format("{}_{:08X}", plugin.substr(0, kPluginInName - 9), whole);
			}
			return std::format("{}_{:06X}_{:08X}_{}.png", plugin, a_item.GetLocalFormID(), ItemView::PictureOf(a_item), kLook);
		}

		std::filesystem::path OnDisk(const std::string& a_name)
		{
			return std::filesystem::path("Data") / kFolder / a_name;
		}

		// A file of any other length is torn by a crash or isn't ours, the game's reader can crash on a made up header, so
		// it counts as missing and gets made over
		bool Baked(const std::string& a_name)
		{
			std::error_code failed;
			return std::filesystem::file_size(OnDisk(a_name), failed) == kFileBytes;
		}

		// What a crash left in the trying file joins the list here, first thing, before anyone writes there again
		const std::unordered_set<std::string>& Skipped()
		{
			static const auto names = [] {
				std::unordered_set<std::string> read;
				std::ifstream kept{ OnDisk(kSkippedFile) };
				for (std::string line; std::getline(kept, line);) {
					read.insert(line);
				}
				std::ifstream trying{ OnDisk(kTryingFile) };
				std::string crashed;
				if (std::getline(trying, crashed) && !crashed.empty() && read.insert(crashed).second) {
					logger::warn("the game went down while making the picture {}, that item keeps its icon from now on. Take its line out of {} to try again", crashed, kSkippedFile);
					std::ofstream{ OnDisk(kSkippedFile), std::ios::app } << crashed << '\n';
				}
				return read;
			}();
			return names;
		}

		// A broken model kills the game inside its own reader and a stack overflow leaves no handler alive, so the name
		// goes to a file first. Found there on the next start that item is never tried again, one crash and the saves
		// load. Windows keeps what was written even if the game dies the next moment
		class Trying
		{
		public:
			explicit Trying(const std::string& a_name) { Say(a_name); }
			~Trying() { Say({}); }

			Trying(const Trying&) = delete;
			Trying& operator=(const Trying&) = delete;

		private:
			static void Say(std::string_view a_name)
			{
				static const HANDLE file = [] {
					Skipped();
					// a window closed in the middle is no crash, the item did nothing wrong
					std::atexit([] { Say({}); });
					std::error_code failed;
					std::filesystem::create_directories(OnDisk(kTryingFile).parent_path(), failed);
					return CreateFileW(OnDisk(kTryingFile).c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
				}();
				if (file == INVALID_HANDLE_VALUE) {
					return;
				}
				DWORD written = 0;
				SetFilePointer(file, 0, nullptr, FILE_BEGIN);
				WriteFile(file, a_name.data(), static_cast<DWORD>(a_name.size()), &written, nullptr);
				SetEndOfFile(file);
			}
		};

		// Flash finds by its address only an image the game was told of, it draws a placeholder for the rest. Each lives
		// while the menu does
		auto& told = *new std::unordered_map<RE::FormID, std::unique_ptr<RE::BSScaleformExternalTexture>>();
		// oldest first, a list of thousands of items holds this many images at most, about 20 MB
		std::deque<RE::FormID> toldInOrder;
		constexpr std::size_t kToldMost = 1024;
		std::vector<RE::FormID> ahead;
		// items already looked for on the disk and not found, one look each until a picture is made
		std::unordered_set<RE::FormID> notOnDisk;
		// A file costs a little and a list going by asks for many. Past this many between two quiet moments of the list a
		// row keeps its icon, so scrolling a huge inventory stays as smooth as without pictures
		constexpr std::uint32_t kLoadsAtOnce = 4;
		std::uint32_t loads = 0;
		// a look at the disk is cheap but thousands of rows not made yet are not, they get spread over the frames
		constexpr std::uint32_t kLooksAtOnce = 24;
		std::uint32_t looks = 0;

		void DropOldest()
		{
			while (told.size() > kToldMost && !toldInOrder.empty()) {
				const auto oldest = toldInOrder.front();
				toldInOrder.pop_front();
				// one in sight stays, its row shows it right now
				if (std::ranges::find(wanted, oldest) != wanted.end()) {
					toldInOrder.push_back(oldest);
					if (std::ranges::all_of(toldInOrder, [](RE::FormID a_item) { return std::ranges::find(wanted, a_item) != wanted.end(); })) {
						return;
					}
					continue;
				}
				told.erase(oldest);
				urls.erase(oldest);
			}
		}

		std::string UrlOf(RE::FormID a_item, const std::string& a_name)
		{
			const auto path = std::format("Textures/InventoryReforged/Items/{}", a_name);
			auto texture = std::make_unique<RE::BSScaleformExternalTexture>();
			texture->filePath = path.c_str();
			if (!texture->LoadPNG(path.c_str())) {
				logger::warn("the game didn't take the picture {}", path);
				return {};
			}
			told[a_item] = std::move(texture);
			toldInOrder.push_back(a_item);
			DropOldest();
			return "img://" + path;
		}

		bool Ready(RE::NiAVObject& a_model)
		{
			bool ready = true;
			Scene::Visit(a_model, [&](RE::NiAVObject& a_part) {
				auto* shape = a_part.AsGeometry();
				auto* lighting = shape ? netimmerse_cast<RE::BSLightingShaderProperty*>(shape->GetGeometryRuntimeData().shaderProperty.get()) : nullptr;
				const auto* material = lighting ? static_cast<RE::BSLightingShaderMaterialBase*>(lighting->material) : nullptr;
				if (material && (!material->diffuseTexture || !material->diffuseTexture->rendererTexture)) {
					ready = false;
				}
			});
			return ready;
		}

		struct Grid
		{
			std::uint32_t pitch = 0;
			std::vector<std::uint8_t> bytes;
		};

		// The same item over black and over white tells what it covers and how much, glow and glass included. The picture
		// is shrunk four times for smooth edges, brought to one brightness, and gets a dark line around it so a white bow
		// and a thin blade both stand out on any ground
		std::vector<std::uint8_t> Finish(const Grid& a_black, const Grid& a_white, bool a_redFirst)
		{
			std::vector<float> color(kKept * kKept * 3);
			std::vector<float> cover(kKept * kKept);
			for (std::uint32_t y = 0; y < kDrawn; ++y) {
				const auto* black = a_black.bytes.data() + y * a_black.pitch;
				const auto* white = a_white.bytes.data() + y * a_white.pitch;
				for (std::uint32_t x = 0; x < kDrawn; ++x, black += 4, white += 4) {
					const float through = ((white[0] - black[0]) + (white[1] - black[1]) + (white[2] - black[2])) / (3.0F * 255.0F);
					const float alpha = std::clamp(1.0F - through, 0.0F, 1.0F);
					const auto at = (y / kShrink) * kKept + x / kShrink;
					// over black what is seen is the color already times its cover
					color[at * 3] += black[a_redFirst ? 2 : 0] / 255.0F;
					color[at * 3 + 1] += black[1] / 255.0F;
					color[at * 3 + 2] += black[a_redFirst ? 0 : 2] / 255.0F;
					cover[at] += alpha;
				}
			}
			float bright = 0.0F;
			float covered = 0.0F;
			for (std::size_t at = 0; at < cover.size(); ++at) {
				if (cover[at] > 0.0F) {
					for (int channel = 0; channel < 3; ++channel) {
						color[at * 3 + channel] /= cover[at];
					}
					cover[at] /= static_cast<float>(kShrink * kShrink);
					bright += cover[at] * (0.11F * color[at * 3] + 0.59F * color[at * 3 + 1] + 0.3F * color[at * 3 + 2]);
					covered += cover[at];
				}
			}
			// nothing drawn is no picture, and a model leaves air around itself, so a full square is a read gone wrong. Either
			// would stay for good
			if (covered <= 0.0F || covered >= 0.98F * static_cast<float>(cover.size())) {
				return {};
			}
			const float mean = bright / covered;
			const float gain = mean > 0.0F ? std::clamp(kBrightness / mean, kGainLeast, kGainMost) : 1.0F;
			std::vector<std::uint8_t> done(kKept * kKept * 4);
			for (int y = 0; y < static_cast<int>(kKept); ++y) {
				for (int x = 0; x < static_cast<int>(kKept); ++x) {
					const auto at = static_cast<std::size_t>(y) * kKept + x;
					float around = 0.0F;
					for (int down = std::max(0, y - kOutline); down <= std::min<int>(kKept - 1, y + kOutline); ++down) {
						for (int across = std::max(0, x - kOutline); across <= std::min<int>(kKept - 1, x + kOutline); ++across) {
							around = std::max(around, cover[static_cast<std::size_t>(down) * kKept + across]);
						}
					}
					const float own = cover[at];
					const float line = around * kOutlineStrength * (1.0F - own);
					const float whole = own + line;
					for (int channel = 0; channel < 3; ++channel) {
						const float mine = std::min(color[at * 3 + channel] * gain, 1.0F);
						const float mixed = whole > 0.0F ? (mine * own + kOutlineColor[channel] / 255.0F * line) / whole : 0.0F;
						done[at * 4 + channel] = static_cast<std::uint8_t>(mixed * 255.0F + 0.5F);
					}
					done[at * 4 + 3] = static_cast<std::uint8_t>(std::min(whole, 1.0F) * 255.0F + 0.5F);
				}
			}
			return done;
		}

		bool Write(const std::string& a_name, const std::vector<std::uint8_t>& a_pixels)
		{
			// The game's loader of Flash images reads PNG. The pixels go in stored blocks, nothing compresses them
			const auto big = [](std::vector<std::uint8_t>& a_to, std::uint32_t a_value) {
				for (int shift = 24; shift >= 0; shift -= 8) {
					a_to.push_back(static_cast<std::uint8_t>(a_value >> shift));
				}
			};
			const auto crc = [](const std::uint8_t* a_bytes, std::size_t a_count) {
				std::uint32_t value = 0xFFFFFFFFU;
				for (std::size_t at = 0; at < a_count; ++at) {
					value ^= a_bytes[at];
					for (int bit = 0; bit < 8; ++bit) {
						value = (value >> 1) ^ (0xEDB88320U & (0U - (value & 1U)));
					}
				}
				return ~value;
			};
			std::vector<std::uint8_t> out{ 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A };
			const auto chunk = [&](const char* a_kind, const std::vector<std::uint8_t>& a_data) {
				big(out, static_cast<std::uint32_t>(a_data.size()));
				const auto from = out.size();
				out.insert(out.end(), a_kind, a_kind + 4);
				out.insert(out.end(), a_data.begin(), a_data.end());
				big(out, crc(out.data() + from, out.size() - from));
			};
			std::vector<std::uint8_t> head;
			big(head, kKept);
			big(head, kKept);
			head.insert(head.end(), { 8, 6, 0, 0, 0 });
			chunk("IHDR", head);
			// every line starts with its filter, none, and the file holds red first
			std::vector<std::uint8_t> lines;
			lines.reserve((kKept * 4 + 1) * kKept);
			for (std::uint32_t y = 0; y < kKept; ++y) {
				lines.push_back(0);
				for (std::uint32_t x = 0; x < kKept; ++x) {
					const auto* pixel = a_pixels.data() + (y * kKept + x) * 4;
					lines.insert(lines.end(), { pixel[2], pixel[1], pixel[0], pixel[3] });
				}
			}
			std::vector<std::uint8_t> packed{ 0x78, 0x01 };
			std::size_t done = 0;
			while (done < lines.size()) {
				const auto part = static_cast<std::uint16_t>(std::min<std::size_t>(lines.size() - done, 0xFFFF));
				packed.push_back(done + part == lines.size() ? 1 : 0);
				packed.insert(packed.end(), { static_cast<std::uint8_t>(part), static_cast<std::uint8_t>(part >> 8), static_cast<std::uint8_t>(~part), static_cast<std::uint8_t>(~part >> 8) });
				packed.insert(packed.end(), lines.begin() + static_cast<std::ptrdiff_t>(done), lines.begin() + static_cast<std::ptrdiff_t>(done + part));
				done += part;
			}
			std::uint32_t low = 1;
			std::uint32_t high = 0;
			for (const auto byte : lines) {
				low = (low + byte) % 65521U;
				high = (high + low) % 65521U;
			}
			big(packed, (high << 16) | low);
			chunk("IDAT", packed);
			chunk("IEND", {});
			std::error_code failed;
			std::filesystem::create_directories(OnDisk(a_name).parent_path(), failed);
			std::ofstream file{ OnDisk(a_name), std::ios::binary };
			if (!file) {
				logger::warn("no way to write the picture {}", a_name);
				return false;
			}
			file.write(reinterpret_cast<const char*>(out.data()), static_cast<std::streamsize>(out.size()));
			return file.good();
		}

		// the bound target, the frame it held and the region under the model to read
		struct Target
		{
			ComPtr<ID3D11RenderTargetView> view;
			ComPtr<ID3D11Texture2D> texture;
			ComPtr<ID3D11Texture2D> behind;
			ComPtr<ID3D11Texture2D> read;
			DXGI_FORMAT format = DXGI_FORMAT_UNKNOWN;
			std::uint32_t width = 0;
			std::uint32_t height = 0;
		};
		auto& target = *new Target();

		bool EightBits(DXGI_FORMAT a_format)
		{
			return a_format == DXGI_FORMAT_R8G8B8A8_UNORM || a_format == DXGI_FORMAT_R8G8B8A8_UNORM_SRGB || a_format == DXGI_FORMAT_R8G8B8A8_TYPELESS ||
			       a_format == DXGI_FORMAT_B8G8R8A8_UNORM || a_format == DXGI_FORMAT_B8G8R8A8_UNORM_SRGB || a_format == DXGI_FORMAT_B8G8R8A8_TYPELESS;
		}

		bool Deep(DXGI_FORMAT a_format)
		{
			return a_format == DXGI_FORMAT_R10G10B10A2_UNORM || a_format == DXGI_FORMAT_R10G10B10A2_TYPELESS || a_format == DXGI_FORMAT_R16G16B16A16_FLOAT || a_format == DXGI_FORMAT_R11G11B10_FLOAT;
		}

		bool Prepare(ID3D11Device& a_device, ID3D11DeviceContext& a_context)
		{
			ComPtr<ID3D11RenderTargetView> view;
			a_context.OMGetRenderTargets(1, view.GetAddressOf(), nullptr);
			if (!view) {
				return false;
			}
			ComPtr<ID3D11Resource> resource;
			view->GetResource(resource.GetAddressOf());
			ComPtr<ID3D11Texture2D> texture;
			if (FAILED(resource.As(&texture))) {
				return false;
			}
			D3D11_TEXTURE2D_DESC whole{};
			texture->GetDesc(&whole);
			const bool known = EightBits(whole.Format) || Deep(whole.Format);
			// on a target smaller than the screen an upscaler leaves, the read goes past it, does nothing and the last item's
			// pixels would be kept under this one's name
			const auto screen = RE::BSGraphics::Renderer::GetScreenSize();
			if (!known || whole.SampleDesc.Count != 1 || whole.Width < screen.width || whole.Height < screen.height || whole.Width < kDrawn || whole.Height < kDrawn) {
				logger::warn("item pictures can't be read from a target of format {}, {} samples, {} x {}", std::to_underlying(whole.Format), whole.SampleDesc.Count, whole.Width, whole.Height);
				return false;
			}
			// a copy between textures of different sizes does nothing and says nothing
			if (target.format != whole.Format || target.width != whole.Width || target.height != whole.Height) {
				D3D11_TEXTURE2D_DESC copy{};
				copy.Width = whole.Width;
				copy.Height = whole.Height;
				copy.MipLevels = 1;
				copy.ArraySize = 1;
				copy.Format = whole.Format;
				copy.SampleDesc.Count = 1;
				copy.Usage = D3D11_USAGE_DEFAULT;
				if (FAILED(a_device.CreateTexture2D(&copy, nullptr, target.behind.ReleaseAndGetAddressOf()))) {
					return false;
				}
				copy.Width = kDrawn;
				copy.Height = kDrawn;
				copy.Usage = D3D11_USAGE_STAGING;
				copy.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
				if (FAILED(a_device.CreateTexture2D(&copy, nullptr, target.read.ReleaseAndGetAddressOf()))) {
					return false;
				}
				target.format = whole.Format;
				target.width = whole.Width;
				target.height = whole.Height;
				logger::info("item pictures are read from a target of format {}, {} x {}", std::to_underlying(whole.Format), whole.Width, whole.Height);
			}
			target.view = view;
			target.texture = texture;
			return true;
		}

		float Half(std::uint16_t a_half)
		{
			const int exponent = (a_half >> 10) & 0x1F;
			const float fraction = static_cast<float>(a_half & 0x3FF) / 1024.0F;
			const float value = exponent == 0 ? fraction * std::ldexp(1.0F, -14) : (1.0F + fraction) * std::ldexp(1.0F, exponent - 15);
			return (a_half & 0x8000) != 0 ? -value : value;
		}

		bool Read(ID3D11DeviceContext& a_context, const D3D11_BOX& a_box, Grid& a_grid)
		{
			a_context.CopySubresourceRegion(target.read.Get(), 0, 0, 0, 0, target.texture.Get(), 0, &a_box);
			D3D11_MAPPED_SUBRESOURCE mapped{};
			if (FAILED(a_context.Map(target.read.Get(), 0, D3D11_MAP_READ, 0, &mapped))) {
				return false;
			}
			const auto* from = static_cast<const std::uint8_t*>(mapped.pData);
			if (Deep(target.format)) {
				// Community Shaders and the like draw into deeper targets, every pixel comes down to the eight bits of a picture
				a_grid.pitch = kDrawn * 4;
				a_grid.bytes.resize(static_cast<std::size_t>(a_grid.pitch) * kDrawn);
				for (std::uint32_t y = 0; y < kDrawn; ++y) {
					const auto* line = from + y * mapped.RowPitch;
					auto* to = a_grid.bytes.data() + y * a_grid.pitch;
					for (std::uint32_t x = 0; x < kDrawn; ++x, to += 4) {
						const auto level = [](float a_value) { return static_cast<std::uint8_t>(std::clamp(a_value, 0.0F, 1.0F) * 255.0F + 0.5F); };
						if (target.format == DXGI_FORMAT_R16G16B16A16_FLOAT) {
							std::array<std::uint16_t, 4> halves{};
							std::memcpy(halves.data(), line + x * 8ull, 8);
							for (int channel = 0; channel < 3; ++channel) {
								to[channel] = level(Half(halves[channel]));
							}
						} else {
							std::uint32_t packed = 0;
							std::memcpy(&packed, line + x * 4ull, 4);
							if (target.format == DXGI_FORMAT_R11G11B10_FLOAT) {
								to[0] = level(Half(static_cast<std::uint16_t>((packed & 0x7FF) << 4)));
								to[1] = level(Half(static_cast<std::uint16_t>(((packed >> 11) & 0x7FF) << 4)));
								to[2] = level(Half(static_cast<std::uint16_t>(((packed >> 22) & 0x3FF) << 5)));
							} else {
								to[0] = level((packed & 0x3FF) / 1023.0F);
								to[1] = level(((packed >> 10) & 0x3FF) / 1023.0F);
								to[2] = level(((packed >> 20) & 0x3FF) / 1023.0F);
							}
						}
						to[3] = 255;
					}
				}
			} else {
				a_grid.pitch = mapped.RowPitch;
				a_grid.bytes.assign(from, from + static_cast<std::size_t>(mapped.RowPitch) * kDrawn);
			}
			a_context.Unmap(target.read.Get(), 0);
			return true;
		}

		D3D11_BOX MiddleOfScreen()
		{
			const auto screen = RE::BSGraphics::Renderer::GetScreenSize();
			const auto left = (screen.width - kDrawn) / 2;
			const auto top = (screen.height - kDrawn) / 2;
			return { left, top, 0, left + kDrawn, top + kDrawn, 1 };
		}

		void Keep(const Drawing& a_drawing, const Grid& a_black, const Grid& a_white)
		{
			const auto& name = a_drawing.name;
			const bool redFirst = target.format != DXGI_FORMAT_B8G8R8A8_UNORM && target.format != DXGI_FORMAT_B8G8R8A8_UNORM_SRGB && target.format != DXGI_FORMAT_B8G8R8A8_TYPELESS;
			const auto pixels = Finish(a_black, a_white, redFirst);
			if (pixels.empty()) {
				logger::warn("nothing was drawn of {}", name);
				without.insert(a_drawing.item);
				return;
			}
			if (Write(name, pixels)) {
				notOnDisk.erase(a_drawing.item);
				if (auto url = UrlOf(a_drawing.item, name); !url.empty()) {
					urls[a_drawing.item] = std::move(url);
				} else {
					without.insert(a_drawing.item);
				}
			} else {
				without.insert(a_drawing.item);
			}
		}

		void NoTarget()
		{
			broken = true;
			logger::warn("item pictures stay off, the bound target can't be used");
		}

		void Draw(const Drawing& a_drawing, ID3D11Device& a_device, ID3D11DeviceContext& a_context)
		{
			static const auto work = Profile::Work("item picture drawn");
			const Profile::Timer timer{ work };
			// an empty pass first, in a chest nothing was drawn yet this frame and the target of the menu's 3D isn't bound
			Scene::DrawAlone(*a_drawing.model, false);
			ComPtr<ID3D11DeviceContext1> context1;
			if (!Prepare(a_device, a_context) || FAILED(a_context.QueryInterface(IID_PPV_ARGS(context1.GetAddressOf())))) {
				NoTarget();
				return;
			}
			const auto box = MiddleOfScreen();
			const D3D11_RECT rect{ static_cast<LONG>(box.left), static_cast<LONG>(box.top), static_cast<LONG>(box.right), static_cast<LONG>(box.bottom) };
			a_context.CopyResource(target.behind.Get(), target.texture.Get());

			const auto over = [&](const float a_ground, Grid& a_grid) {
				const std::array<float, 4> ground{ a_ground, a_ground, a_ground, 1.0F };
				context1->ClearView(target.view.Get(), ground.data(), &rect, 1);
				Scene::DrawAlone(*a_drawing.model);
				return Read(a_context, box, a_grid);
			};
			Grid black;
			Grid white;
			const bool read = over(0.0F, black) && over(1.0F, white);
			a_context.CopyResource(target.texture.Get(), target.behind.Get());
			if (read) {
				Keep(a_drawing, black, white);
			} else {
				without.insert(a_drawing.item);
			}
		}

		// The loading screen's pass leaves out whatever blends with what's behind it. A torn page or feathers are nothing
		// else and came out empty, a gem lost its facets. What simply sees through gets cut by its alpha while the picture
		// is drawn. Glow and blood that add to what's under them stay out, solid they would cover it
		class CutBlending
		{
		public:
			explicit CutBlending(RE::NiAVObject& a_model)
			{
				using Blend = RE::NiAlphaProperty::AlphaFunction;
				Scene::Visit(a_model, [&](RE::NiAVObject& a_part) {
					auto* shape = a_part.AsGeometry();
					if (!shape) {
						return;
					}
					auto& data = shape->GetGeometryRuntimeData();
					auto* alpha = data.alphaProperty.get();
					if (!alpha || !alpha->GetAlphaBlending() || alpha->GetSrcBlendMode() != Blend::kSrcAlpha || alpha->GetDestBlendMode() != Blend::kInvSrcAlpha) {
						return;
					}
					cut.push_back({ data.alphaProperty, data.shaderProperty, alpha->alphaFlags, alpha->alphaThreshold });
					alpha->SetAlphaBlending(false);
					alpha->SetAlphaTesting(true);
					alpha->alphaThreshold = std::max(alpha->alphaThreshold, kCutLeast);
					Rethink(data.shaderProperty.get());
				});
			}

			~CutBlending()
			{
				for (const auto& one : cut) {
					one.alpha->alphaFlags = one.flags;
					one.alpha->alphaThreshold = one.threshold;
					Rethink(one.shader.get());
				}
			}

			CutBlending(const CutBlending&) = delete;
			CutBlending& operator=(const CutBlending&) = delete;

		private:
			static constexpr std::uint8_t kCutLeast = 32;

			struct Cut
			{
				RE::NiPointer<RE::NiAlphaProperty> alpha;
				RE::NiPointer<RE::BSShaderProperty> shader;
				std::uint16_t flags;
				std::uint8_t threshold;
			};

			// a shader keeps its passes until told this state is new, they were picked by the flags it had
			static void Rethink(RE::BSShaderProperty* a_shader)
			{
				if (a_shader) {
					a_shader->lastRenderPassState = std::numeric_limits<std::int32_t>::max();
				}
			}

			std::vector<Cut> cut;
		};

		// The loading screen's own pass wipes its whole target black before it draws, so the frame goes aside for that
		// time and no ground of ours survives to compare with. Light turned far up shows what a model covers instead,
		// every pixel of it comes out bright and the rest stays black
		void DrawOnLoadingScreen(const Drawing& a_drawing, ID3D11Device& a_device, ID3D11DeviceContext& a_context)
		{
			static const auto work = Profile::Work("item picture drawn");
			const Profile::Timer timer{ work };
			if (!Prepare(a_device, a_context)) {
				NoTarget();
				return;
			}
			const auto shown = target.texture;
			const auto frame = target.behind;
			a_context.CopyResource(frame.Get(), shown.Get());

			Scene::DrawAlone(*a_drawing.model);
			// what the pass drew into is bound now
			if (!Prepare(a_device, a_context)) {
				a_context.CopyResource(shown.Get(), frame.Get());
				NoTarget();
				return;
			}
			const auto box = MiddleOfScreen();
			Grid black;
			Grid lit;
			bool read = Read(a_context, box, black);
			if (read) {
				const Scene::EvenAmbient blinding{ kAmbientToTellCover };
				Scene::DrawAlone(*a_drawing.model);
				read = Read(a_context, box, lit);
			}
			a_context.CopyResource(shown.Get(), frame.Get());
			if (!read || black.pitch != lit.pitch) {
				without.insert(a_drawing.item);
				return;
			}
			// the same as if it had been drawn over white, where it covers nothing shows the white
			Grid white = black;
			for (std::uint32_t y = 0; y < kDrawn; ++y) {
				const auto* from = lit.bytes.data() + y * lit.pitch;
				auto* to = white.bytes.data() + y * white.pitch;
				for (std::uint32_t x = 0; x < kDrawn; ++x, from += 4, to += 4) {
					if (from[0] <= kNoCover && from[1] <= kNoCover && from[2] <= kNoCover) {
						to[0] = to[1] = to[2] = 255;
					}
				}
			}
			Keep(a_drawing, black, white);
		}

		RE::NiPointer<RE::NiAVObject> ModelOf(RE::TESForm& a_item, const std::string& a_name)
		{
			const Trying trying{ a_name };
			return ItemView::PictureModel(a_item, kRoom * static_cast<float>(kDrawn) / static_cast<float>(RE::BSGraphics::Renderer::GetScreenSize().height));
		}
	}

	std::string Url(RE::FormID a_item)
	{
		if (const auto found = urls.find(a_item); found != urls.end()) {
			return found->second;
		}
		if (without.contains(a_item) || notOnDisk.contains(a_item) || loads >= kLoadsAtOnce || looks >= kLooksAtOnce) {
			return {};
		}
		auto* form = RE::TESForm::LookupByID(a_item);
		const auto name = form ? FileName(*form) : std::string();
		if (name.empty() || Skipped().contains(name)) {
			without.insert(a_item);
			return {};
		}
		++looks;
		if (!Baked(name)) {
			notOnDisk.insert(a_item);
			return {};
		}
		++loads;
		auto url = UrlOf(a_item, name);
		if (url.empty()) {
			without.insert(a_item);
			return {};
		}
		return urls[a_item] = std::move(url);
	}

	void Want(const std::vector<RE::FormID>& a_items)
	{
		wanted = a_items;
	}

	void Ahead(const std::vector<RE::FormID>& a_items)
	{
		ahead = a_items;
	}

	bool Waiting()
	{
		if (broken) {
			return false;
		}
		const auto open = [](RE::FormID a_item) { return !urls.contains(a_item) && !without.contains(a_item); };
		const bool room = told.size() < kToldMost;
		return std::ranges::any_of(wanted, open) || std::ranges::any_of(ahead, [&](RE::FormID a_item) { return open(a_item) && (room || notOnDisk.contains(a_item)); });
	}

	void Grow(bool a_idle)
	{
		loads = 0;
		looks = 0;
		if (broken) {
			return;
		}
		for (const auto item : wanted) {
			Url(item);
		}
		for (const auto item : ahead) {
			if (loads >= kLoadsAtOnce || looks >= kLooksAtOnce || told.size() >= kToldMost) {
				break;
			}
			Url(item);
		}
		if (drawing) {
			return;
		}
		const auto next = [](const std::vector<RE::FormID>& a_items) {
			for (const auto item : a_items) {
				if (notOnDisk.contains(item) && !without.contains(item)) {
					auto* form = RE::TESForm::LookupByID(item);
					auto name = form ? FileName(*form) : std::string();
					auto model = form ? ModelOf(*form, name) : nullptr;
					if (!model) {
						without.insert(item);
						continue;
					}
					Scene::AddHidden(*model);
					drawing = Drawing{ item, std::move(name), model, std::chrono::steady_clock::now() };
					return true;
				}
			}
			return false;
		};
		if (!next(wanted) && a_idle) {
			next(ahead);
		}
	}

	void Frame()
	{
		if (!drawing || broken) {
			return;
		}
		const auto waited = std::chrono::steady_clock::now() - drawing->since;
		if (waited < kTexturesWaitLeast || (waited < kTexturesWaitMost && !Ready(*drawing->model))) {
			return;
		}
		auto* renderer = RE::BSGraphics::Renderer::GetSingleton();
		auto* device = renderer ? reinterpret_cast<ID3D11Device*>(renderer->GetRuntimeData().forwarder) : nullptr;
		auto* context = renderer ? reinterpret_cast<ID3D11DeviceContext*>(renderer->GetRuntimeData().context) : nullptr;
		if (device && context) {
			const Scene::EvenAmbient ambient{ Settings::Get().menuAmbient };
			const Scene::TemporalBlend blend{ false };
			const Trying trying{ drawing->name };
			Draw(*drawing, *device, *context);
		}
		Scene::Remove(*drawing->model);
		ItemView::LetGo(drawing->model);
		drawing.reset();
	}

	namespace
	{
		// models get read ahead of the one drawn, their textures come in meanwhile, and the screen keeps moving
		constexpr std::size_t kReadAhead = 8;
		constexpr auto kLoadingScreenGone = std::chrono::seconds(3);
		constexpr auto kLoadWaitMost = std::chrono::minutes(5);
		// a hoard of thousands doesn't hold one load for minutes, the next loads and the menu make the rest
		constexpr auto kBakeMost = std::chrono::seconds(60);
		// this many without one picture and the screen isn't one to draw on here, the menu makes them as it opens
		constexpr std::size_t kLoadTries = 8;

		struct Load
		{
			std::vector<RE::FormID> items;
			std::chrono::steady_clock::time_point began;
			std::size_t next = 0;
			std::size_t drawn = 0;
			std::size_t made = 0;
			std::deque<Drawing> reading;
			// the bar's values release into their movie, so it stays alive as long as they do
			RE::GPtr<RE::GFxMovieView> movie;
			RE::GFxValue bar;
			RE::GFxValue label;
			float barWidth = 0.0F;
		};
		auto& load = *new Load();
		// the screen's thread draws frames while the main one starts the next load
		std::mutex loadLock;
		std::atomic<bool> loading{ false };
		std::atomic<std::int64_t> lastFrame{ 0 };

		std::int64_t NowMs()
		{
			return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
		}

		void AddCarried(RE::Actor& a_actor, std::unordered_set<RE::FormID>& a_seen, std::vector<RE::FormID>& a_items)
		{
			auto* changes = a_actor.GetInventoryChanges();
			if (!changes || !changes->entryList) {
				return;
			}
			for (const auto* entry : *changes->entryList) {
				const auto* object = entry ? entry->object : nullptr;
				if (!object || !a_seen.insert(object->GetFormID()).second || !object->GetPlayable()) {
					continue;
				}
				const auto name = FileName(*object);
				if (!Skipped().contains(name) && !Baked(name)) {
					a_items.push_back(object->GetFormID());
				}
			}
		}

		void ShowBar(RE::IMenu& a_menu)
		{
			auto* movie = a_menu.uiMovie.get();
			if (!movie) {
				return;
			}
			if (load.bar.IsUndefined()) {
				RE::GFxValue root;
				if (!movie->GetVariable(&root, "_root") || !root.IsObject()) {
					return;
				}
				load.movie = a_menu.uiMovie;
				const auto frame = movie->GetVisibleFrameRect();
				const float width = (frame.right - frame.left) * 0.3F;
				const float left = (frame.left + frame.right - width) / 2.0F;
				// under the hint of the loading screen, that one grows up from the bottom on the right
				const float top = frame.top + (frame.bottom - frame.top) * 0.95F;
				const float high = 4.0F;
				const auto box = [&](const char* a_name, double a_depth, double a_color, double a_alpha, float a_width, RE::GFxValue& a_clip) {
					std::array<RE::GFxValue, 2> made{ RE::GFxValue(a_name), RE::GFxValue(a_depth) };
					root.Invoke("createEmptyMovieClip", &a_clip, made.data(), made.size());
					std::array<RE::GFxValue, 2> fill{ RE::GFxValue(a_color), RE::GFxValue(a_alpha) };
					a_clip.Invoke("beginFill", nullptr, fill.data(), fill.size());
					const auto line = [&](const char* a_how, float a_x, float a_y) {
						std::array<RE::GFxValue, 2> at{ RE::GFxValue(static_cast<double>(a_x)), RE::GFxValue(static_cast<double>(a_y)) };
						a_clip.Invoke(a_how, nullptr, at.data(), at.size());
					};
					line("moveTo", 0.0F, 0.0F);
					line("lineTo", a_width, 0.0F);
					line("lineTo", a_width, high);
					line("lineTo", 0.0F, high);
					line("lineTo", 0.0F, 0.0F);
					a_clip.Invoke("endFill", nullptr, nullptr, 0);
					a_clip.SetMember("_x", static_cast<double>(left));
					a_clip.SetMember("_y", static_cast<double>(top));
				};
				RE::GFxValue back;
				box("equipmentBakeBack", 9000.0, 0x000000, 55.0, width, back);
				box("equipmentBakeBar", 9001.0, 0xD8C89A, 100.0, width, load.bar);
				load.bar.SetMember("_xscale", 0.0);
				std::array<RE::GFxValue, 6> field{ RE::GFxValue("equipmentBakeText"), RE::GFxValue(9002.0), RE::GFxValue(static_cast<double>(left)), RE::GFxValue(static_cast<double>(top - 26.0F)),
					RE::GFxValue(static_cast<double>(width)), RE::GFxValue(24.0) };
				root.Invoke("createTextField", nullptr, field.data(), field.size());
				root.GetMember("equipmentBakeText", &load.label);
				RE::GFxValue format;
				std::array<RE::GFxValue, 3> look{ RE::GFxValue("$EverywhereMediumFont"), RE::GFxValue(16.0), RE::GFxValue(static_cast<double>(0xD8C89A)) };
				movie->CreateObject(&format, "TextFormat", look.data(), look.size());
				format.SetMember("align", "center");
				load.label.Invoke("setNewTextFormat", nullptr, &format, 1);
				load.label.SetMember("embedFonts", true);
				load.label.SetMember("selectable", false);
			}
			const auto done = std::min(load.drawn, load.items.size());
			load.bar.SetMember("_xscale", 100.0 * static_cast<double>(done) / static_cast<double>(std::max<std::size_t>(load.items.size(), 1)));
			const auto words = std::format("{} {} / {}", Translations::Word("$IR_Preparing item pictures"), done, load.items.size());
			load.label.SetMember("text", words.c_str());
		}

		void DropBar()
		{
			load.bar = RE::GFxValue();
			load.label = RE::GFxValue();
			load.movie.reset();
		}

		void HideBar()
		{
			RE::GFxValue root;
			if (load.movie && load.movie->GetVariable(&root, "_root")) {
				for (const auto* name : { "equipmentBakeBack", "equipmentBakeBar", "equipmentBakeText" }) {
					RE::GFxValue clip;
					if (root.GetMember(name, &clip) && clip.IsObject()) {
						clip.Invoke("removeMovieClip", nullptr, nullptr, 0);
					}
				}
			}
			DropBar();
		}

		void DropReading()
		{
			for (auto& one : load.reading) {
				Scene::Remove(*one.model);
				ItemView::LetGo(one.model);
			}
			load.reading.clear();
		}

		// This thread holds the load back and also owns the window. Without its messages Windows calls the game not
		// responding, right what the bar is there to prevent. False when the game was told to quit
		bool KeepWindowAlive()
		{
			MSG message{};
			while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
				if (message.message == WM_QUIT) {
					PostQuitMessage(static_cast<int>(message.wParam));
					return false;
				}
				TranslateMessage(&message);
				DispatchMessageW(&message);
			}
			return true;
		}
	}

	void DrawOnLoad()
	{
		auto* player = RE::PlayerCharacter::GetSingleton();
		if (broken || !player || !Settings::Get().rowModels) {
			return;
		}
		std::unordered_set<RE::FormID> seen;
		{
			const std::lock_guard locker{ loadLock };
			// a load that gave up may have left these if its screen drew no frame after
			DropReading();
			DropBar();
			load = {};
		}
		AddCarried(*player, seen, load.items);
		if (auto* lists = RE::ProcessLists::GetSingleton()) {
			for (const auto& handle : lists->highActorHandles) {
				const auto actor = handle.get();
				if (actor && actor->IsPlayerTeammate()) {
					AddCarried(*actor, seen, load.items);
				}
			}
		}
		logger::info("item pictures to make as the save loads: {} of {} things carried, the screen's light scheme is {}", load.items.size(), seen.size(), std::to_underlying(RE::UI3DSceneManager::GetSingleton()->currentlightScheme));
		if (load.items.empty()) {
			return;
		}
		lastFrame = NowMs();
		load.began = std::chrono::steady_clock::now();
		loading = true;
		const auto until = std::chrono::steady_clock::now() + kLoadWaitMost;
		while (loading && KeepWindowAlive() && std::chrono::steady_clock::now() < until && NowMs() - lastFrame < std::chrono::duration_cast<std::chrono::milliseconds>(kLoadingScreenGone).count()) {
			std::this_thread::sleep_for(std::chrono::milliseconds(10));
		}
		if (loading) {
			logger::warn("the loading screen didn't wait for the item pictures, {} of {} were made", load.drawn, load.items.size());
		}
		loading = false;
	}

	void LoadingFrame(RE::IMenu& a_menu)
	{
		const std::lock_guard locker{ loadLock };
		if (!loading) {
			if (!load.reading.empty()) {
				DropReading();
			}
			if (!load.bar.IsUndefined()) {
				HideBar();
			}
			return;
		}
		lastFrame = NowMs();
		auto* renderer = RE::BSGraphics::Renderer::GetSingleton();
		auto* device = renderer ? reinterpret_cast<ID3D11Device*>(renderer->GetRuntimeData().forwarder) : nullptr;
		auto* context = renderer ? reinterpret_cast<ID3D11DeviceContext*>(renderer->GetRuntimeData().context) : nullptr;
		if (!device || !context) {
			loading = false;
			return;
		}
		const auto finish = [&]() {
			DropReading();
			HideBar();
			logger::info("item pictures made as the save loaded: {} of {}", load.made, load.items.size());
			// what failed here gets its try in the menu
			without.clear();
			loading = false;
		};
		while (load.reading.size() < kReadAhead && load.next < load.items.size()) {
			const auto item = load.items[load.next++];
			auto* form = RE::TESForm::LookupByID(item);
			auto name = form ? FileName(*form) : std::string();
			auto model = form ? ModelOf(*form, name) : nullptr;
			if (!model) {
				++load.drawn;
				continue;
			}
			Scene::AddHidden(*model);
			load.reading.push_back(Drawing{ item, std::move(name), model, std::chrono::steady_clock::now() });
			break;
		}
		if (!load.reading.empty()) {
			auto& first = load.reading.front();
			const auto waited = std::chrono::steady_clock::now() - first.since;
			if (waited >= kTexturesWaitMost || (waited >= kTexturesWaitLeast && Ready(*first.model))) {
				{
					const Scene::ScreenLights lights;
					const Scene::EvenAmbient ambient{ Settings::Get().menuAmbient };
					const Scene::TemporalBlend blend{ false };
					const CutBlending cut{ *first.model };
					const Trying trying{ first.name };
					DrawOnLoadingScreen(first, *device, *context);
				}
				if (urls.contains(first.item)) {
					++load.made;
				}
				Scene::Remove(*first.model);
				ItemView::LetGo(first.model);
				load.reading.pop_front();
				++load.drawn;
				const bool tooLong = std::chrono::steady_clock::now() - load.began >= kBakeMost;
				if (broken || tooLong || (load.made == 0 && load.drawn >= kLoadTries)) {
					finish();
					return;
				}
			}
		}
		ShowBar(a_menu);
		if (load.reading.empty() && load.next >= load.items.size()) {
			finish();
		}
	}

	void Clear()
	{
		wanted.clear();
		if (drawing) {
			Scene::Remove(*drawing->model);
			ItemView::LetGo(drawing->model);
			drawing.reset();
		}
		target = {};
		urls.clear();
		told.clear();
		toldInOrder.clear();
		ahead.clear();
		notOnDisk.clear();
		loads = 0;
		looks = 0;
	}
}
