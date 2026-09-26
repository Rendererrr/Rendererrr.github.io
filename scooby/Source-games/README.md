# Source Games

## Half-Life 1

`Half-Life 1/` contains the shared Windows x86 module for Half-Life, Opposing Force
and Blue Shift:

- `ScoobyGoldSrc.dll` and matching `halflife_attach.exe`.
- `lang/valve`, `lang/gearbox`, `lang/bshift`, each with all 23 language catalogs and the current shared UI labels.
- `package.json` with per-file SHA-256 hashes and `THIRD_PARTY.txt` notices.

Fonts, icons, built-in pages, API docs and starter Lua are embedded in the DLL.
Starter scripts are generated automatically in each title's writable user-data
folder; edited scripts are preserved. Keep the DLL, helper and lang files together.

DLL SHA-256: `c23992cf204e5e900b2b4ad4561db21d16bb101925b80150bef8d43852875b44`.
The compact package passed 28 CTests, embedded-resource hash verification and
467 loader distribution/operation checks. These are resource, package and loader
fixture results; this rebuild was not injected into a game. Existing zero feature
verification masks, unavailable pSilent and unverified Linux/Proton/Wine remain.

## Half-Life: Source

Add the separate compact `Half-Life-Source/` package only after its existing owner
finishes and verifies it: its own DLL/helper, language catalogs, hash manifest and
notices, with embedded resources and generated starter scripts. Development DLLs
are not staged as finished packages. The existing coordinator tracks this delivery.

## Maintenance

The old per-title DLLs/asset tree and expanded Candidate4 package were removed from
this distribution. Exact rollback copies and archives remain in the Scooby-Op build
evidence, outside this folder. Archives, debug symbols, research and tests do not
belong in these compact game folders.

From Scooby-Op, run `python Loader/Main-Loader/tools/stage_source_games.py --check`
to verify the current package. New staging requires the reviewed compact archive
and SHA-256. See `docs/SOURCE_GAMES_DISTRIBUTION.md` in that repository for commands.
Keep the package-local Git rules; they preserve exact manifest-pinned bytes.

This change is local. No commit, push, deployment or live download was performed.
