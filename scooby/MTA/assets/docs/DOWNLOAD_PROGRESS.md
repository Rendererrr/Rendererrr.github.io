# Shared download progress

## Compact product status card (2026-10-08)

L4D and TF2 opt into `DownloadProgressOptions::compact`, matching the GTA5/RDR2 card: 410 px nominal width, 8 px corners, two text rows, a 4 px accent bar and a 28 px bottom margin, all scaled/clamped to the viewport. The right-hand status is muted and uses `Working` when the total is unknown. Hosts show `Game assets` and received file counts; the detail row shows checking/extraction status or the current transfer filename and byte counts. Failure details are clipped independently of the visible F5 retry hint. The standard layout remains the default for other callers. Download verification, worker state and retry behavior are unchanged.

The shared preview accepts a final `compact` argument after its accent argument, and `extracting` as the phase, for example `simple_base_download_progress_preview output.png 1280 extracting v2 1 default compact`. Run `download_progress` for both layouts and inspect download/extraction/failure captures; these are synthetic UI checks, separate from HTTPS and native gameplay acceptance.

V1 (`UI`), V2 (`UI-v2`) and the combined selector (`UI-vboth`) compile the same `src/ui/download_progress.cpp`. Include `simple_base/ui/download_progress.h` and link `simple_base_ui`. API revision remains 1: this is additive and does not alter existing feature, profile or Lua IDs.

```cpp
// After CreateContext, before the first renderer NewFrame; optional for bootstrap hosts.
simple_base::ui::theme(); // The linked edition supplies the theme.
ImGui::GetIO().FontDefault = simple_base::ui::addDownloadProgressFont();

// Between ImGui::NewFrame and ImGui::Render, on the render thread.
simple_base::ui::DownloadProgress progress;
progress.filename = "fonts/NotoSans.ttf";
progress.received = receivedBytes;
progress.total = totalBytes;
simple_base::ui::DownloadProgressOptions options;
options.scale = dpiScale;
simple_base::ui::drawDownloadProgress(progress, options);
```

The active PopupBg/FrameBg/Text/TextDisabled/SliderGrab colors and popup/frame rounding come from the current theme. V1 uses its charcoal/cyan palette and subtle rounding; V2 uses its square surfaces and brighter cyan. Custom accents are inherited. Once the application is running, omit bootstrap initialization to retain its selected language font and theme. Combined hosts may call `themeV1()` during bootstrap; TF2 reads its existing selected edition and accent before creating the full menu.

The card is a passive foreground draw, bottom-centered and clamped/scaled to the viewport. It does not create an interactive window, alter global style, capture input, read settings, start network work or implement retry. Hosts own download state, verification, cancellation and retry keys. Checking with an unknown total uses an indeterminate segment. Received bytes are bounded by the total; long filenames/messages use UTF-8-safe ellipsis. Paused states retain the filename and show the error plus retry hint. Colors and font are borrowed; callers retain font lifetime.

The always-available bootstrap scope embeds a 21,108-byte Latin subset of the same Noto Sans menu family, its SIL OFL license and provenance. It remains available with `SIMPLE_BASE_EMBED_SHARED_ASSETS=OFF`, without restoring the large multilingual fonts to the DLL. Checked-in resources do not require fontTools during normal builds. Regeneration uses `scripts/build_bootstrap_font.py` with `fonttools==4.60.1`; the source hash, axes, Unicode coverage and result hash are recorded in `resources/bootstrap/provenance.json`. Install regeneration dependencies under `build/`, never beside source.

Root solutions: `UI/SimpleBase.sln`, `UI-v2/SimpleBaseV2.sln`, and `UI-vboth/SimpleBaseBoth.sln`. They support Release/Debug and x64/Win32 via the existing CMake toolchain. V1/V2 generated outputs use `build/windows-x64` and `build/windows-x86`; combined outputs use `build/combined-x64` and `build/combined-x86`. Prerequisites: Visual Studio 2022 Desktop C++, CMake and Python 3.9+. No fontTools dependency is needed to build.

Run each edition's full x64/Win32 CTest suites, including `download_progress`, then inspect shared preview captures. `simple_base_download_progress_preview <absolute output.png> <width> <download|failure> [v1|v2] [scale] [orange]` uses a hidden WARP window and a synthetic transfer. This checks presentation only; it does not establish HTTPS, game input/reset or performance acceptance. Canonical hosts require rebuilding to receive the component.
