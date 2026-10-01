# Megabonk resources

`lang/index.json` describes the 23 UTF-8 language catalogs in `lang/`, including byte sizes and SHA-256 hashes. Megabonk embeds this same collection for first launch and can download updates from its Interface settings. Edited local catalogs are preserved.

Generate this collection from `Scooby-Op/More Games/Megabonk/tools/build_languages.py`, which combines canonical Simple-base UI translations and Megabonk phrases. Copy the generated `assets/lang/*.json` here as a complete collection. Core game controls are translated; untranslated details retain English fallback, with coverage counts in the index.

The DLL uses the raw GitHub path `Rendererrr/Rendererrr.github.io/main/scooby/Megabonk/lang/`. Local copies require the normal repository publication before that endpoint changes. No game DLL or launcher is stored in this resource folder.
