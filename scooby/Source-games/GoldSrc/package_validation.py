#!/usr/bin/env python3
"""Deterministic preview ZIP and dependency/hash validation (Python 3.10+)."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import struct
import zipfile
import sys
sys.dont_write_bytecode = True
from runtime_launcher import inspect_pe

ROOT = Path(__file__).resolve().parent
SYSTEM_DLLS = {
    "kernel32.dll", "user32.dll", "gdi32.dll", "advapi32.dll", "shell32.dll", "ole32.dll",
    "oleaut32.dll", "comdlg32.dll", "comctl32.dll", "shlwapi.dll", "imm32.dll", "version.dll",
    "winmm.dll", "dwmapi.dll", "d3d11.dll", "dxgi.dll", "d3dcompiler_47.dll", "windowscodecs.dll",
    "ntdll.dll", "setupapi.dll", "bcrypt.dll", "crypt32.dll", "msimg32.dll", "uxtheme.dll",
}

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def imports(exe: Path) -> list[str]:
    data = exe.read_bytes()
    def unpack(fmt, pos): return struct.unpack_from(fmt, data, pos)
    pe, = unpack("<I", 60)
    sections, = unpack("<H", pe + 6)
    optional_size, = unpack("<H", pe + 20)
    optional = pe + 24
    magic, = unpack("<H", optional)
    directory = optional + (112 if magic == 0x20B else 96)
    section_table = optional + optional_size
    def offset(rva):
        for n in range(sections):
            size, address, raw_size, raw = unpack("<IIII", section_table + n * 40 + 8)
            if address <= rva < address + max(size, raw_size):
                result = raw + rva - address
                if result < len(data): return result
        raise ValueError(f"Invalid PE RVA {rva:x}")
    def name(rva):
        start = offset(rva)
        return data[start:data.index(b"\0", start, start + 256)].decode("ascii").lower()
    result = set()
    for index, stride, name_index in ((1, 20, 3), (13, 32, 1)):
        rva, size = unpack("<II", directory + index * 8)
        if not rva: continue
        base = offset(rva)
        for pos in range(base, base + size, stride):
            entry = unpack("<" + "I" * (stride // 4), pos)
            if not any(entry): break
            if index == 13 and entry[0] != 1:
                raise ValueError("Unsupported delay-import address format")
            result.add(name(entry[name_index]))
    return sorted(result)

def safe_name(name: str) -> bool:
    path = PurePosixPath(name)
    return bool(name) and not path.is_absolute() and "\\" not in name and ":" not in name and all(
        part not in ("", ".", "..") for part in name.split("/"))

def verify_payload(payload: dict[str, bytes]) -> dict:
    if "package.json" not in payload: raise ValueError("Missing package.json")
    manifest = json.loads(payload["package.json"])
    expected = manifest["files"]
    if set(payload) != set(expected) | {"package.json"}: raise ValueError("Unexpected/missing package files")
    seen = set()
    for name, record in expected.items():
        if not safe_name(name) or name.casefold() in seen: raise ValueError("Unsafe/case-colliding package name")
        seen.add(name.casefold())
        if len(payload[name]) != record["size"] or sha(payload[name]) != record["sha256"]:
            raise ValueError(f"Package hash mismatch: {name}")
    return manifest

def verify_archive(path: Path) -> dict:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or any(not safe_name(n) for n in names):
            raise ValueError("Unsafe or duplicate ZIP member")
        if sum(i.file_size for i in archive.infolist()) > 512 * 1024 * 1024:
            raise ValueError("Package exceeds validation size limit")
        return verify_payload({n: archive.read(n) for n in names})

def verify_directory(root: Path) -> dict:
    manifest = json.loads((root / "package.json").read_text(encoding="utf-8"))
    payload = {"package.json": (root / "package.json").read_bytes()}
    for name in manifest["files"]:
        if not safe_name(name): raise ValueError("Unsafe package member")
        path = root / name
        if path.is_symlink() or root.resolve() not in path.resolve().parents:
            raise ValueError("Package member escapes package root")
        payload[name] = path.read_bytes()
    return verify_payload(payload)

def build(exe: Path, assets: Path, arch: str, output: Path) -> dict:
    image = inspect_pe(exe, expected_arch=arch)
    dependencies = imports(exe)
    unknown = set(dependencies) - SYSTEM_DLLS
    if unknown: raise ValueError(f"Unpackaged runtime imports: {sorted(unknown)}. Build with static MSVC runtime.")
    payload = {"bin/simple_base_preview.exe": exe.read_bytes()}
    for path in sorted(assets.rglob("*")):
        if path.is_symlink(): raise ValueError(f"Asset symlink unsupported: {path}")
        if path.is_file() and not path.name.startswith(".simple-base-assets"):
            payload["bin/assets/" + path.relative_to(assets).as_posix()] = path.read_bytes()
    required = ("fonts/NotoSans.ttf", "fonts/NotoSansMono.ttf", "fonts/lucide.ttf",
                "fonts/LUCIDE-LICENSE.txt", "docs/shared/THIRD_PARTY.md", "docs/shared/README.md")
    for name in required:
        if "bin/assets/" + name not in payload: raise ValueError(f"Required asset/license absent: {name}")
    for name in ("Dear-ImGui-LICENSE.txt", "ImGuiColorTextEdit-LICENSE.txt", "Lua-LICENSE.txt", "nlohmann-json-LICENSE.txt"):
        if "bin/assets/licenses/" + name not in payload: raise ValueError(f"Missing library license: {name}")
    font_manifest = json.loads(payload["bin/assets/fonts/manifest.json"])
    for font in font_manifest["fonts"]:
        name = font["file"]
        if not safe_name(name): raise ValueError("Unsafe font manifest path")
        data = payload.get("bin/assets/fonts/" + name, b"")
        if len(data) != font["size"] or sha(data) != font["sha256"]:
            raise ValueError(f"Font differs from pinned manifest: {name}")
        license_name = "bin/assets/fonts/licenses/" + Path(name).stem + "-OFL.txt"
        if license_name not in payload: raise ValueError(f"Missing font license: {name}")
    for name in ("launch.py", "launch.sh", "runtime_launcher.py", "package.py", "README.md"):
        # Scripts/docs have canonical LF independent of Git's Windows checkout settings.
        payload[name] = (ROOT / name).read_text(encoding="utf-8-sig").replace("\r\n", "\n").encode("utf-8")
    manifest = {"schema_version": 1, "product": "SimpleBasePreview", "architecture": arch,
                "api_revision": (ROOT.parent / "api-revision.txt").read_text().strip(),
                "executable_sha256": image["sha256"], "runtime": "static-msvc",
                "system_imports": dependencies, "linux_runtime_verified": False,
                "files": {n: {"size": len(v), "sha256": sha(v)} for n, v in sorted(payload.items())}}
    payload["package.json"] = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    verify_payload(payload)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo(name, (2020, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (0o100755 if name == "launch.sh" else 0o100644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data, compresslevel=9)
    verify_archive(output)
    output.with_suffix(output.suffix + ".sha256").write_text(sha(output.read_bytes()) + "  " + output.name + "\n", encoding="ascii")
    return manifest

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", type=Path)
    parser.add_argument("--exe", type=Path)
    parser.add_argument("--assets", type=Path)
    parser.add_argument("--arch", choices=("x86", "x64"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        if args.verify:
            result = verify_directory(args.verify) if args.verify.is_dir() else verify_archive(args.verify)
        else:
            if not all((args.exe, args.assets, args.arch, args.output)): parser.error("Build requires --exe --assets --arch --output")
            result = build(args.exe, args.assets, args.arch, args.output)
        print(json.dumps({k: result[k] for k in ("product", "architecture", "runtime", "system_imports", "linux_runtime_verified")}, indent=2))
        return 0
    except (ValueError, OSError, KeyError, struct.error, zipfile.BadZipFile) as error:
        print(f"Package validation failed: {error}")
        return 2

if __name__ == "__main__": raise SystemExit(main())
