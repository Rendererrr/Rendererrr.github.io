# GoldSrc unified Windows module under Proton/Wine

This local package targets the Windows x86 Steam game through its selected Wine/Proton runner. Actual Linux gameplay, graphics, input and lifecycle acceptance are pending a Linux test host. Native Linux/ELF games and Steam Deck/Game Mode are not verified targets. A successful dry run validates local files/options only.

Keep the whole package together. The Windows helper, unified ScoobyGoldSrc.dll and all three product asset scopes, fonts, languages, Lua pages and licenses are included. The package uses the static MSVC runtime; the runner provides Windows/OpenGL system libraries. `package.json` pins every included file. No Windows system DLLs or installed game binaries are copied into the package.

Start this exact Windows game in Steam with OpenGL and a local single-player map. No `-insecure` option is required. The adapter independently checks executable, engine, client, server profile, product, App ID and local session. It does not support native Linux game processes or arbitrary modifications. Spawn and trainer capabilities remain pending until that exact platform/profile has acceptance evidence.

Use Python 3.10 or newer. Pick the same runner/prefix as the game; the launcher never initializes, deletes or repairs a prefix. For Proton, select the package's Steam App ID (Half-Life 70; Opposing Force 50; Blue Shift 130):

```sh
./launch.sh --product halflife --runner proton --appid 70 --list
./launch.sh --product halflife --runner proton --appid 70 --game-exe '/path/to/SteamLibrary/steamapps/common/Half-Life/hl.exe' --diagnose
./launch.sh --product halflife --runner proton --appid 70 --game-exe '/path/to/SteamLibrary/steamapps/common/Half-Life/hl.exe' --pid 1234
```

The PID must be the Windows PID printed by `--list` in that runner/prefix, never a Linux PID. Use --product opposingforce with App ID50, or --product blueshift with App ID130, in this same unified package. List output includes the full process image path; select the intended library. The helper resolves the adjacent DLL using its own Windows module path, so spaces/Unicode and alternate drive mappings do not require a guessed `Z:` path.

For plain Wine, choose the game's already initialized prefix and exact Wine executable:

```sh
./launch.sh --product halflife --runner wine --wine '/path/to/runner/bin/wine' --prefix '/path/to/game-prefix' --list
./launch.sh --product halflife --runner wine --wine '/path/to/runner/bin/wine' --prefix '/path/to/game-prefix' --game-exe '/path/to/Half-Life/hl.exe' --pid 1234
```

The shared runner supports `--flatpak` Protontricks and `--compat-data` where needed. `--dry-run`/`--diagnose` never launch a runner. `--report /new/private/report.json` creates a scoped diagnostic without credentials or inherited environment contents. There is no silent runner switching. Wrong architecture, native executables, altered package files and mismatched package App IDs are rejected.

The game module writes logs/configs under its user's LOCALAPPDATA/Scooby scope inside the selected prefix, further separated by product, engine, Windows/Wine environment, exact profile and campaign. Assets remain read-only beside the DLL. `SCOOBY_PORT_DATA_ROOT` optionally chooses an absolute root as seen by that Windows process. Current tests use a separate root. Unscoped legacy data is not imported; product namespaces stay isolated. Game restart is required to replace a pinned module; Stop restores owned player/input state and suspends effects.

## Local build/package

From a Visual Studio 2022 developer environment:

```powershell
cmake -S ports -B ports/build/compatibility-windows-x86 -G 'Visual Studio 17 2022' -A Win32 '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded$<$<CONFIG:Debug>:Debug>'
cmake --build ports/build/compatibility-windows-x86 --config Release --parallel 6
ctest --test-dir ports/build/compatibility-windows-x86 -C Release --output-on-failure
python ports/linux/package.py --product goldsrc --bin ports/build/compatibility-windows-x86/Release --helper ports/build/compatibility-windows-x86/Release/halflife_attach.exe --output ports/build/packages/goldsrc-compatibility-x86.zip
python ports/linux/package.py --verify ports/build/packages/goldsrc-compatibility-x86.zip
```

The same DLL and package serve all three verified profiles; assets/valve, assets/gearbox and assets/bshift remain separate. This local package is not a publishing step; retain the SDK's included licensing restrictions.

## Linux acceptance still required

Record exact package/game hashes, distribution/kernel, CPU/GPU/driver, Steam type, runner/version, prefix, display session and OpenGL version. Test startup, process selection, fonts/languages, physical keyboard/relative mouse, focus, resize/fullscreen/minimize, config/hotkeys/Lua isolation, actual chams/animation and campaign features, save/load/death/maps/disconnect/Stop, restart and suspend/resume. Keep Wine and Proton results separate. Linux capabilities stay unverified until these real game runs finish.
