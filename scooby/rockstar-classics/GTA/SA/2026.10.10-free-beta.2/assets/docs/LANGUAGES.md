# Shared language coverage

`languages.json` defines the 23 supported language codes, names, tags and text directions. The editable catalogs are in `assets/languages`. English defines the required common UI labels. Game-only catalogs remain sparse overlays: build staging merges them with every shared catalog, preserving the full shared language set. A host with only an English overlay still receives all shared languages; untranslated game-specific text retains the existing English fallback.

`sync_assets.py` now refuses a missing required language, missing common label, empty/invalid text or a changed printf placeholder before writing staged files. `scripts/language_catalogs.py` checks the canonical files independently, and the `language_catalogs` CTest runs in each shared test build. The source of a new language must be added to `languages.json` and supplied with complete shared labels and appropriate font coverage.

For a language-only change, run:

```powershell
python -X utf8 scripts/language_catalogs.py
python -X utf8 tests/test_sync_assets.py
python -X utf8 scripts/audit_language_coverage.py
```

Run the `ui_and_esp` and `embedded_resources` tests on Win32 and x64 to check language switching and actual glyph coverage. The consumer audit reads paused projects' build integration and merges catalogs in memory; it does not resume, build or launch them. Existing compiled fonts are embedded. Do not add external font directories to compact distributions.

Compact GoldSrc contains all 23 catalogs in each of `lang/valve`, `lang/gearbox` and `lang/bshift`. A catalog-only package can reuse a verified frozen DLL/helper if no embedded resources or runtime code changed; stage the new catalogs, regenerate package hashes, verify the unchanged binary resources and run the real loader install/repair tests. Keep the previous complete package for rollback. HLS uses the same 23-language merge plus its game overlays, but remains subject to its own game acceptance before release.

Main Loader embeds its own 23 JSON packs through its Windows resources. Its separate generator and validator are `Loader/Main-Loader/tools/generate_language_packs.py` and `validate_language_packs.py`. New enum values append to preserve saved language IDs. General translation review is separate from file/key/format and glyph validation; no game, Linux or Proton/Wine acceptance is implied by these checks.
