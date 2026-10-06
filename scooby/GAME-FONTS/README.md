# Downloaded GTA V and RDR2 menu fonts

Both ClickUI's existing font selectors and ListUI > Settings > Fonts include
72 GTA V and 18 RDR2 faces, including distinct HUD/editor/web variants. Choices
are independent between the menus, and ListUI retains its seven role settings.
The catalog is visible before the download finishes. A missing or invalid file
uses the existing default while keeping the saved selection. Download completion
requests an atlas rebuild on the renderer thread. The download worker never
mutates the atlas or selector vectors. Numeric/symbol faces merge the existing
ImGui Latin fallback so navigation remains readable; language fallbacks remain
unchanged. Only selected faces are loaded into the atlas.

## Download and cache

Both games use the same external pack:
`https://raw.githubusercontent.com/Rendererrr/Rendererrr.github.io/main/scooby/GAME-FONTS/Game-Fonts.zip`.
It is staged locally at `Rendererrr.github.io/scooby/GAME-FONTS/`, with
`asset-packs.json` and `font-catalog.json`. No commit, push or publication is part
of this change. Fresh runtime downloads need the hosted pack published first.

Each game installs into its own `C:/scooby/<GTA5 or RDR2>/Fonts/Game/` directory.
This cache is separate from Windows fonts, custom language files and translation
font caches. The installer uses a separate cancellable worker joined at shutdown,
existing download progress, HTTPS, archive size/SHA-256 pins and manifest checks.
Files use short stable names to avoid Windows path-length problems. No Windows
font installation is performed. Saved selectors use readable stable family names.

A downloaded font buffer must match its individual size and SHA-256 before it
reaches ImGui. Missing/wrong-size files are repaired by the existing pack installer.
A same-size locally corrupted font is rejected and uses the default; remove that
cache file and relaunch to repair it. Failed transfers retain existing cache files.
No font bytes or translation catalogs are embedded in the DLL. RDR2_TRANSLATIONS,
Windows-first language fallback and the mandatory resource guard are unchanged.

## Scope and provenance

The 72 GTA fonts are every TTF in DrunkSonic/gta-v-fonts at
`cec3bcc09dca3f61c78fbecb31c1067241839c3f`. That source explicitly describes its
extraction as incomplete; this is not a claim that every font in every GTA build,
locale, DLC or artwork is included. The 18 RDR2 fonts are every TTF in
ExpMero/rdr2_fonts at `ec9728d424bb171bf410aec86391ce1eb5a832f0`.
The pack preserves both source READMEs, per-file source URLs and SHA-256 hashes.

The GTA source restricts use to personal, research and educational contexts and
prohibits commercial use. Local staging does not grant redistribution rights;
resolve that restriction before commercial distribution. RDR2's source does not
supply a redistribution license. No public release was performed.

## Reproduce and verify

Run `python tools/package_game_fonts.py` to recreate the pinned pack under
`build/.internal/game-font-pack/`; it downloads exact source revisions and does not
publish. If intentionally changing the inventory, regenerate GameFontCatalog.hpp
family/path/size/hash metadata in both projects and update HostedAssetPacks.hpp
from the emitted pack.json before staging the matching pack. Keep source notices.
The two catalog/fallback headers and packaging/test scripts must stay identical.

From an x64 Visual Studio developer prompt:

```text
python tools/test_game_fonts.py <absolute-path-to-Game-Fonts.zip>
python tools/test_asset_downloads.py
python tools/test_listui_fonts.py
```

The font suite uses production installation, SHA-256 validation and Latin fallback
with each game's actual ImGui: all 90 files, corrupted/truncated buffers, atlas
baking, navigation glyphs, cancellation, offline repeat install, missing-file
repair and one-shot refresh notification. Logs/fixtures stay under
`build/.internal/game-font-tests/`. The existing suites cover installer failures
and ListUI role isolation/persistence. Full builds use the project's root solution
and existing build commands in UPDATING.md. When launched from PowerShell 7,
RDR2 staging requires the child Windows PowerShell module path to include
`$env:SystemRoot/System32/WindowsPowerShell/v1.0/Modules` for Get-FileHash.

Evidence and pre-change source/Release backups are under
`build/.internal/game-fonts-20261007/`. The 636 font checks, 35 installer checks
and 30 ListUI font checks passed per game. RDR2's 56 CTests passed.
Both final Release builds passed; RDR2 also passed the mandatory embedded-language
resource guard. Artifact hashes and source consistency are recorded in
`build/.internal/game-fonts-20261007/acceptance.json`. Live published HTTP,
in-game appearance, switching/renderer resets and foreground FPS remain untested.
