# Dependency provenance

- UI: copied from `source/L4D-Debug/vendor/simple-base/UI` on 2026-09-22, then independently extended with optional normalized engine-projected geometry and returned ESP statistics. Its [THIRD_PARTY.md](shared/vendor/UI/THIRD_PARTY.md), bundled licenses and font licenses remain with the snapshot.
- FreeType: copied from `source/L4D-Debug/vendor/freetype`; see that distribution's license files.
- MinHook: copied from `source/L4D-Debug/vendor/minhook`; license retained in the distribution.
- GoldSrc headers: Valve's official [Half-Life SDK](https://github.com/ValveSoftware/halflife), commit `b1b5cf5892918535619b2937bb927e46cb097ba1`. Selected SDK directories common, engine, pm_shared and public. Original notices are retained, including the SDK's restrictions on commercial distribution. This task does not publish or distribute the port.
- Studio file identifiers are documented in that SDK's `utils/studiomdl/studiomdl.h`.

IDA is used on workspace copies of the user's installed binaries. Game binaries and IDA databases are not included in source control. The recorded disassembly excerpts and SHA-256 inventory document the adapter's provenance.

