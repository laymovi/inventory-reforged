#include "PCH.h"

#include "Debug/Pace.h"

#include "Profile.h"

namespace Debug::Pace
{
	namespace
	{
		using Clock = std::chrono::steady_clock;

		constexpr auto kWindow = std::chrono::seconds(10);
		constexpr auto kMemoryEvery = std::chrono::seconds(60);
		// a menu draws the world's frame too with Skyrim Souls RE and the like, that frame is the menu's then
		constexpr auto kMenuHolds = std::chrono::milliseconds(250);
		// longer than this is a load or a pause of the game, no frame anyone plays
		constexpr double kNoFrameMs = 1000.0;
		constexpr double kHitchMs = 50.0;
		constexpr std::size_t kHitchesTold = 6;
		constexpr std::size_t kMostFrames = 8192;
		constexpr double kShare = 99.0;
		constexpr double kMegabyte = 1024.0 * 1024.0;

		struct Window
		{
			std::string where;
			Clock::time_point since;
			std::vector<float> frames;
			double own = 0.0;
			float ownLongest = 0.0F;
			std::size_t hitches = 0;
			std::vector<std::string> hitchesTold;
		};

		std::optional<Window> window;
		std::optional<Clock::time_point> last;
		std::uint64_t ownAtLast = 0;
		Clock::time_point menuFrameAt{};
		Clock::time_point memoryAt{};
		std::uint64_t memoryBefore = 0;

		void Tell(const Window& a_window, Clock::time_point a_now)
		{
			if (a_window.frames.empty()) {
				return;
			}
			auto frames = a_window.frames;
			std::ranges::sort(frames);
			const auto count = frames.size();
			const double total = std::accumulate(frames.begin(), frames.end(), 0.0);
			const double seconds = std::chrono::duration<double>(a_now - a_window.since).count();
			const auto share = frames[std::min(count - 1, static_cast<std::size_t>(count * kShare / 100.0))];
			std::string hitches;
			for (const auto& one : a_window.hitchesTold) {
				hitches += (hitches.empty() ? ": " : ", ") + one;
			}
			logger::info("pace of {}, {:.1f} s: {} frames, {:.0f} fps, middle {:.2f} ms, 99% {:.2f} ms, longest {:.1f} ms; the mod {:.3f} ms a frame ({:.2f}% of the time), at most {:.2f} ms in one; {} frames over {:.0f} ms{}",
				a_window.where, seconds, count, seconds > 0.0 ? static_cast<double>(count) / seconds : 0.0, frames[count / 2], share, frames.back(), a_window.own / static_cast<double>(count),
				total > 0.0 ? a_window.own / total * 100.0 : 0.0, a_window.ownLongest, a_window.hitches, kHitchMs, hitches);
		}
	}

	void Frame(std::string_view a_where)
	{
		const auto now = Clock::now();
		const bool menu = a_where != "world";
		if (menu) {
			menuFrameAt = now;
		} else if (now - menuFrameAt < kMenuHolds) {
			return;
		}
		const auto own = Profile::OwnNanoseconds();
		if (last) {
			const double frame = std::chrono::duration<double, std::milli>(now - *last).count();
			const auto ownMs = static_cast<float>(static_cast<double>(own - ownAtLast) / 1e6);
			if (window && (window->where != a_where || now - window->since >= kWindow)) {
				Tell(*window, now);
				window.reset();
			}
			if (!window) {
				window = Window{ .where = std::string(a_where), .since = now };
			}
			if (frame < kNoFrameMs && window->frames.size() < kMostFrames) {
				window->frames.push_back(static_cast<float>(frame));
				window->own += ownMs;
				window->ownLongest = std::max(window->ownLongest, ownMs);
				if (frame >= kHitchMs) {
					++window->hitches;
					if (window->hitchesTold.size() < kHitchesTold) {
						window->hitchesTold.push_back(fmt::format("{:.0f} ms with {:.1f} ms of the mod", frame, ownMs));
					}
				}
			}
		}
		last = now;
		ownAtLast = own;
		if (now - memoryAt >= kMemoryEvery) {
			memoryAt = now;
			const auto memory = Profile::GameMemory();
			logger::info("pace: the game holds {:.0f} MB ({:+.0f} MB since the last minute)", static_cast<double>(memory) / kMegabyte,
				memoryBefore == 0 ? 0.0 : (static_cast<double>(memory) - static_cast<double>(memoryBefore)) / kMegabyte);
			memoryBefore = memory;
		}
	}
}
