# Vendored dependencies

- **Dear ImGui**: 1.92.7 WIP (`IMGUI_VERSION_NUM=19262`), copied as one consistent set from this repository's UI project. MIT license in `third_party/imgui/LICENSE.txt`. Includes matching Win32, DX11, DX12, OpenGL3 and Vulkan backends. Upstream: https://github.com/ocornut/imgui
- **ImGuiColorTextEdit**: copied from the GMod project with its Lua lexer and local input/scrolling improvements. MIT license in `third_party/text_editor/LICENSE`. Upstream: https://github.com/BalazsJako/ImGuiColorTextEdit
- **nlohmann/json**: single-header library from the GMod project; MIT copyright/license retained in `third_party/json/json.hpp`. Upstream: https://github.com/nlohmann/json
- **Lua**: 5.4.7 C sources from the existing Megabonk UI dependency. Copyright and MIT license retained at the end of `third_party/lua/lua.h`. `lua.c`, `luac.c` and `onelua.c` are excluded from the static library target. Upstream: https://www.lua.org/
- **Lucide icon font**: copied from the GMod assets. License retained in `assets/fonts/LUCIDE-LICENSE.txt`. Upstream: https://lucide.dev/

Verdana, Segoe UI Semibold and Consolas can be loaded from the user's Windows installation; they are not redistributed here. Bundled Noto faces provide fallback and merged glyph coverage; their pinned revisions/checksums are in `assets/fonts/manifest.json` and their OFL notices in `assets/fonts/licenses/`. ImGui's font is the final fallback. Supply appropriately licensed font files in `assets/fonts` when bundling a custom look or broader glyph coverage.

Keep the ImGui core and renderer backends on matching versions when updating them. See `docs/PORTING.md` for the dynamic-font texture update requirement.

The L4D host enables the optional FreeType rasterizer, using its statically built FreeType 2.14.3 dependency. The official v1.92.6 FreeType adapter is included under `third_party/imgui/misc/freetype` and tested against the current font-loader API. The local DX9 backend additionally honors framebuffer scale for viewport, scissor and half-pixel projection. See the host's `docs/FONTS.md` and `research/validation/font-dependencies.json` for provenance and notices.
