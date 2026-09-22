# Source Games distribution staging

## Current Half-Life 1 package

- `GoldSrc/bin/ScoobyGoldSrc.dll` is the unified Windows x86 module for Half-Life 1, Opposing Force and Blue Shift.
- `GoldSrc/bin/halflife_attach.exe` is its matching helper. Keep the complete `GoldSrc/bin/assets/valve`, `gearbox` and `bshift` directories with them.
- `GoldSrc/package.json` pins every extracted payload file. The package also includes fonts, languages, Lua pages, scripts, documentation, licenses and runner files.
- `goldsrc-compatibility-x86.zip` and its `.sha256` sidecar contain the same complete package.

The staged artifact is the frozen Candidate4 handoff. Archive SHA-256: `391065a4ca68677cdb84888a52f9457ca0987a87ac7463c19200a8d97e621306`. DLL SHA-256: `16119d4e30f15913166f8d484ab1de2f5a2e5869d69ce5faf44dd809239371d8`.

Package hashes are verified. Full Candidate4 gameplay acceptance across all three titles remains incomplete; native capability masks remain zero, pSilent is unavailable, and Linux/Proton/Wine runtime is unverified. Staging does not enable authenticated Main Loader downloading or module loading.

## Legacy per-title staging

The older files and index below are retained separately. Use the complete `GoldSrc` package above for the current shared module.

Local staging only. No commit, push or release was performed.

- `ScoobyHalfLife.dll`: exact accepted native Windows x86/OpenGL Half-Life build; archive and DLL hashes are pinned in `manifest.json`.
- `ScoobyOpposingForce.dll`: separate development package, still in validation. Do not advertise campaign acceptance from the original game.
- `Half-life-1/lang`, `fonts`, `scripts`, Lua pages, `docs` and licenses belong to original Half-Life.
- `Half-life-1/Opposing-Force` contains the separate expansion assets.

The distribution names are not an installed module layout. The manifest maps each file to its runtime `install_path`: in particular, `lang` installs as `assets/languages`, and each edition keeps its own module-adjacent `assets` directory. Keep writable profiles outside package assets. Do not share versioned Lua/config namespaces between editions.

Main-loader now provides Source Games navigation, the Half-Life dashboard, edition selection, normal Steam launch, guide/features and folder links. Authenticated product entitlement and download/module-loading integration remain pending; no new access policy was invented. Linux runtime acceptance remains unverified. Blue Shift and Half-Life: Source have no staged DLLs.
