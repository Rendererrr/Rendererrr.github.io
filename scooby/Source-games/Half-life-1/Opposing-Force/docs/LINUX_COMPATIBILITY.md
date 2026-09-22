# Canonical UI compatibility checkpoint — 2026-09-22

Status: **implemented and Windows build-tested; Linux runtime unverified**. The deliverables are Windows x86/x64 PE preview packages for explicit Wine/Proton use. Win32 host guards stay in place. Native ELF hosting, actual game-module behavior, Steam Deck/Game Mode, Wine graphics/input and loader authentication require their own acceptance environments.

## Shared contract and changes

- `core/environment.h` exposes `runtimeEnvironment()` (process architecture and Wine/version metadata), wide Windows `environmentPath()`, and `defaultUserDataDirectory(product)`. Product IDs are single stable ASCII names. User roots must be absolute; lookup never creates directories or falls back to the install location. Windows/Wine data defaults to `%LOCALAPPDATA%/Scooby/<product>`. Portable core uses absolute XDG data or HOME on other systems; that branch was not executed on this Windows host.
- `core/files.h` exposes UTF-8/filesystem path conversion. FileStore Unicode names are validated as Unicode scalar sequences; existing separator/traversal/reserved ASCII names are rejected. Profiles/scripts use wide Windows paths, list names as UTF-8, and retain atomic replacement. Localization lookup and the icon font path now preserve UTF-8.
- Under Wine, shared fonts use bundled licensed Noto/Lucide faces rather than unverified Windows system-font substitutions. Native Windows retains its system-font preference. Optional FreeType remains consumer-controlled.
- `Dx11Host` reports actual driver, feature level and HRESULT. Failed/partial device creation is cleaned up; Wine never silently switches to WARP. Native Windows fallback remains, with accurate reporting. `--warp` is an explicit diagnostic choice, not a DXVK or Linux acceptance claim.
- Preview data, COM/window/renderer initialization and capture failures produce nonzero status. `--diagnostics` and smoke reports record individual observations. Hidden smoke explicitly skips fullscreen/minimize; visible fullscreen is recorded as issued and needs visual confirmation. Application/Lua objects are destroyed before the ImGui context. Incomplete smoke runs no longer claim success.
- The shared `linux/runtime_launcher.py`, factored by the Main-loader owner, keeps selected runner/prefix/App ID explicit, validates PE architecture and optional Windows game/module pairs, rejects native binaries, and provides read-only planning plus opt-in private reports. Plans do not prove a running process match. Runtime metadata never enables a game feature or replaces authentication/integrity checks.

Adapters own their exact game/profile/mode identity, assets and lifecycle. GoldSrc/Half-Life campaign and Deathmatch remain distinct. GMod has its own ImGui/runtime and consumes the runner contract through its owner; it has not been relabeled a canonical UI consumer. No paused Random-games title was resumed.

## Build/package workflow

See [the packaged instructions](../linux/README.md). `linux/build.ps1 -Architecture Both` builds/test-checks static-MSVC x86/x64 Windows previews and creates deterministic ZIPs under `build/compatibility-packages`. Package validation checks PE architecture, exact system imports, all file hashes, pinned font hashes and bundled licenses. No system DLLs or runner binaries are copied from the development machine. ZIP timestamps/order/permissions/line endings are fixed; identical input bytes produce identical ZIP bytes. Whole-toolchain reproducibility is not claimed.

Local output evidence lives in `build/compatibility-validation.json`, including final ZIP/EXE hashes, native test-report paths, source hashes and consumer results. It is intentionally outside staged docs to avoid recursively embedding a package's own hash into its assets. SHA-256 sidecars and package.json also accompany the ZIPs. Build outputs are ignored, and were not published.

## Windows control-host evidence

| Test | Result and limit |
| --- | --- |
| Shared x86 Release / static MSVC | 7/7 CTests: core, UI/ESP, appearance, Lua API, 16-case asset sync, Unicode/environment/Lua lifecycle, 4-case package integrity suite |
| Shared x64 Release / static MSVC | Same 7/7 CTests |
| Runner plan fixtures | 31/31 reported by Main-loader owner; x86 prefixes, PE mismatch/native rejection, report redaction/exclusive creation; no runner executed |
| Packaged x86 + x64 native preview | Both passed in ACL-enforced read-only Unicode install folders, with separate Unicode user-data folders; no package bytes or files changed |
| Native graphics | Explicit DX11/WARP, hidden 150-frame resize/device recreation; PNG capture, config flush, Thai 150% capture at 960x650; hidden fullscreen/minimize skipped |
| Failure path | Non-directory data root returns exit 5; no install-folder fallback |
| L4D representative consumer | Build passed; 19/20 CTests in initial snapshot. All canonical/UI/DX9/OpenGL/input/font/Lua checks passed; game-specific target-reacquisition assertion sent to owner |
| GoldSrc representative consumer | Half-Life/Opposing Force DLLs built; 16/16 CTests passed after owner fixed namespace omissions in its new campaign test |

Visual inspection of the native Thai capture confirms rendered text/icons, not a comprehensive language/IME/shaping certification. DX12/OpenGL shared backend libraries compile; standalone preview uses DX11. Vulkan is disabled. L4D native renderer tests belong to that consumer snapshot, not Wine results. No game was launched or attached by this task.

## Required Linux acceptance

This Windows host has no Wine installation or WSL/Linux environment. The master already has a pending Linux/Steam Deck environment question. No OS, boot settings, user prefix or graphics overrides were installed/modified.

For each claimed runtime record distro/kernel, CPU/GPU/driver, display session, Steam native/Flatpak/Game Mode, selected runner and version, actual prefix/App ID, Windows game/module architecture, package/module SHA and API revision. Run the steps in [linux/README.md](../linux/README.md): clean startup, exact process identity, fonts/input/focus/clipboard, scaling and window lifecycle, config/Lua isolation, restart/suspend and failure recovery. Product owners additionally validate actual gameplay transitions/restoration, module handshake, or authentication/TLS/download integrity. Keep every Linux acceptance row unverified until it runs on that environment.

Primary contracts: repository `docs/LINUX_COMPATIBILITY.md`, `docs/HALF_LIFE_FEATURES.md`; [Valve Proton](https://github.com/ValveSoftware/Proton), [Protontricks](https://github.com/Matoking/protontricks), [DXVK](https://github.com/doitsujin/dxvk).
