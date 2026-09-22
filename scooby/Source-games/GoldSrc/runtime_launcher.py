#!/usr/bin/env python3
"""Launch the Windows loader in an explicitly selected Wine/Proton environment."""
from __future__ import annotations

import argparse
import hashlib
import time
import json
import os
from pathlib import Path
import platform
import re
import shutil
import struct
import subprocess
import sys
from dataclasses import dataclass


class LaunchError(ValueError):
    pass


@dataclass
class LaunchPlan:
    command: list[str]
    environment: dict[str, str]
    cwd: Path
    details: dict[str, object]


# A launcher started from another Steam game must not accidentally inherit its
# prefix/runner. Graphics overrides are deliberately left to the selected runner.
RUNTIME_VARIABLES = (
    "WINEPREFIX", "WINEARCH", "WINELOADER", "WINESERVER", "PROTON_VERSION",
    "STEAM_COMPAT_DATA_PATH", "STEAM_COMPAT_TOOL_PATHS", "STEAM_COMPAT_APP_ID",
    "SteamAppId", "SteamGameId",
)


def parser(default_exe: Path | None = None, expected_arch: str = "x64",
           description: str | None = None) -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=description or __doc__)
    p.add_argument("--runner", choices=("wine", "proton"), required=True)
    p.add_argument("--exe", type=Path, default=default_exe or Path(__file__).resolve().parent / "bin" / "ScoobyLoader.exe")
    p.add_argument("--prefix", type=Path, help="Existing 64-bit Wine prefix used by the game (Wine mode).")
    p.add_argument("--wine", help="Wine executable used by the game; defaults to wine on PATH.")
    p.add_argument("--appid", help="Steam App ID whose Proton installation/prefix to use.")
    p.add_argument("--compat-data", type=Path, help="Custom Steam compatdata directory containing pfx.")
    p.add_argument("--protontricks", help="Custom protontricks-launch executable.")
    p.add_argument("--flatpak", action="store_true", help="Use Flatpak Protontricks (Linux/Steam Deck).")
    p.add_argument("--dry-run", action="store_true", help="Validate and show the launch command without starting anything.")
    p.add_argument("--diagnose", action="store_true", help="Validate configuration and print a JSON report without launching.")
    p.add_argument("--game-exe", type=Path, help="Optional Windows game EXE to verify; native ELF/Mach-O targets are rejected.")
    p.add_argument("--module", type=Path, help="Optional DLL preflight; requires --game-exe and matching PE architecture.")
    p.add_argument("--report", type=Path, help="Write a new private JSON diagnostic file; never overwrite an existing report.")
    p.set_defaults(expected_arch=expected_arch)
    return p


def executable(value: str, env: dict[str, str]) -> str:
    # Resolve a program name or explicit path, never a shell expression.
    candidate = Path(value).expanduser()
    if candidate.is_file():
        if os.name != "nt" and not os.access(candidate, os.X_OK):
            raise LaunchError(f"Runner is not executable: {candidate}")
        return str(candidate.resolve())
    found = shutil.which(value, path=env.get("PATH", ""))
    if not found:
        raise LaunchError(f"Runner not found: {value}. Install it or specify its executable path.")
    return found


def inspect_pe(path: Path, *, dll: bool = False, expected_arch: str | None = None) -> dict[str, object]:
    path = path.expanduser().resolve()
    if not path.is_file():
        raise LaunchError(f"Windows {'DLL' if dll else 'EXE'} not found: {path}")
    with path.open("rb") as f:
        dos = f.read(64)
        if len(dos) != 64 or dos[:2] != b"MZ":
            raise LaunchError(f"Expected a Windows PE {'DLL' if dll else 'EXE'}: {path}. Native ELF/Mach-O binaries are unsupported.")
        offset = struct.unpack_from("<I", dos, 60)[0]
        if offset < 64 or offset > path.stat().st_size - 26:
            raise LaunchError(f"Invalid PE header: {path}")
        f.seek(offset)
        pe = f.read(26)
        machine = struct.unpack_from("<H", pe, 4)[0]
        optional_magic = struct.unpack_from("<H", pe, 24)[0]
        arch = {0x14C: "x86", 0x8664: "x64"}.get(machine)
        if pe[:4] != b"PE\0\0" or not arch or optional_magic != (0x10B if arch == "x86" else 0x20B):
            raise LaunchError(f"Unsupported or malformed PE architecture: {path}")
        if bool(struct.unpack_from("<H", pe, 22)[0] & 0x2000) != dll:
            raise LaunchError(f"Expected a Windows {'DLL' if dll else 'EXE'}: {path}")
        if expected_arch and expected_arch != arch:
            raise LaunchError(f"Expected {expected_arch}, found {arch}: {path}")
        f.seek(0)
        digest = hashlib.sha256()
        for block in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(block)
    return {"path": str(path), "architecture": arch, "format": "PE", "sha256": digest.hexdigest()}


def validate_exe(path: Path, expected_arch: str = "x64") -> Path:
    return Path(inspect_pe(path, expected_arch=expected_arch)["path"])


def validate_prefix(path: Path, expected_arch: str = "x64") -> Path:
    path = path.expanduser().resolve()
    if not (path / "drive_c").is_dir() or not (path / "system.reg").is_file() or not (path / "user.reg").is_file():
        raise LaunchError(f"Not an initialized Wine prefix: {path}. Start the game once with its chosen runner first.")
    with (path / "system.reg").open("r", encoding="utf-8", errors="replace") as f:
        header = f.read(4096)
    if expected_arch == "x64" and re.search(r"^#arch=win32\s*$", header, re.MULTILINE):
        raise LaunchError("The selected prefix is 32-bit; the loader requires a 64-bit-capable game prefix.")
    return path


def make_plan(args: argparse.Namespace, forwarded: list[str], *, host: str | None = None,
              environment: dict[str, str] | None = None) -> LaunchPlan:
    host = host or platform.system()
    if host not in ("Linux", "Darwin"):
        raise LaunchError("Run this launcher on Linux or macOS. On Windows, open ScoobyLoader.exe directly.")
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        raise LaunchError("Run as your normal desktop user, without sudo/root.")
    env = dict(os.environ if environment is None else environment)
    for key in RUNTIME_VARIABLES:
        env.pop(key, None)
    loader = inspect_pe(args.exe, expected_arch=args.expected_arch)
    exe = Path(loader["path"])
    details: dict[str, object] = {
        "schema_version": 1, "status": "planned", "linux_runtime_verified": False,
        "host": host, "host_machine": platform.machine(), "runner": args.runner,
        "loader": str(exe), "loader_image": loader,
        "checks": [],
        "in_game_loading": "unverified; requires a compatible Windows game and DLL in this environment",
        "system_tools": "Windows-only; unavailable in compatibility mode",
    }
    if args.runner == "wine":
        if args.appid or args.compat_data or args.flatpak or args.protontricks:
            raise LaunchError("--appid, --compat-data, --flatpak and --protontricks are Proton-only options.")
        if not args.prefix:
            raise LaunchError("Wine mode requires --prefix pointing to the game's existing prefix.")
        prefix = validate_prefix(args.prefix, args.expected_arch)
        env["WINEPREFIX"] = str(prefix)
        command = [executable(args.wine or "wine", env), str(exe), *forwarded]
        details["prefix"] = str(prefix)
    else:
        if host != "Linux":
            raise LaunchError("Proton mode is Linux-only. Use an installed macOS-compatible Wine runner with --runner wine.")
        if args.prefix or args.wine:
            raise LaunchError("Proton selects its Wine runner/prefix through Steam; use --appid and optionally --compat-data.")
        if not args.appid or not re.fullmatch(r"[1-9][0-9]{0,9}", args.appid) or int(args.appid) > 0xFFFFFFFF:
            raise LaunchError("Proton mode requires a valid positive numeric --appid from your Steam installation.")
        if args.flatpak and args.protontricks:
            raise LaunchError("Choose either --flatpak or --protontricks.")
        if args.compat_data:
            compat = args.compat_data.expanduser().resolve()
            prefix = validate_prefix(compat / "pfx", args.expected_arch)
            details["prefix"] = str(prefix)
            env["STEAM_COMPAT_DATA_PATH"] = str(compat)
            details["compat_data"] = str(compat)
        details["appid"] = args.appid
        details["prefix_selection"] = "Resolved by Protontricks from this Steam App ID at launch"
        if args.flatpak:
            command = [executable("flatpak", env), "run", "--command=protontricks-launch"]
            # Scoped, per-invocation access. No persistent Flatpak overrides.
            command.append(f"--filesystem={exe.parent}")
            if args.compat_data:
                command.extend([f"--filesystem={env['STEAM_COMPAT_DATA_PATH']}",
                                f"--env=STEAM_COMPAT_DATA_PATH={env['STEAM_COMPAT_DATA_PATH']}"])
            command.append("com.github.Matoking.protontricks")
        else:
            command = [executable(args.protontricks or "protontricks-launch", env)]
        command += ["--appid", args.appid, str(exe), *forwarded]
    if args.module and not args.game_exe:
        raise LaunchError("--module requires --game-exe for an architecture comparison.")
    if args.game_exe:
        game = inspect_pe(args.game_exe)
        details["game_image"] = game
        if args.module:
            details["module_image"] = inspect_pe(args.module, dll=True, expected_arch=str(game["architecture"]))
        details["checks"].append({"name": "target_architecture", "status": "passed",
                                  "detail": "PE file preflight only; no running process selected and no module loaded"})
    else:
        details["checks"].append({"name": "target_architecture", "status": "unknown", "detail": "No --game-exe supplied"})
    details["checks"].append({"name": "same_runtime_process", "status": "unknown",
                              "detail": "Requires an in-prefix process probe; file preflight does not prove process identity"})
    details["checks"].append({"name": "runner_version", "status": "unknown",
                              "detail": "Runner executable resolved; no external command executed during planning"})
    # Informational context only: these variables confer no entitlements and are
    # never used as a replacement for game/process/authentication checks.
    for key in tuple(env):
        if key.startswith("SCOOBY_COMPAT_"):
            env.pop(key)
    context = {"SCOOBY_COMPAT_RUNNER": args.runner,
               "SCOOBY_COMPAT_APP_ID": args.appid or "",
               "SCOOBY_COMPAT_PREFIX": str(details.get("prefix", ""))}
    env.update(context)
    if args.flatpak:
        insert = command.index("com.github.Matoking.protontricks")
        command[insert:insert] = [f"--env={key}={value}" for key, value in context.items()]
    return LaunchPlan(command, env, exe.parent, details)


def diagnostic_report(plan: LaunchPlan) -> dict[str, object]:
    # Do not serialize forwarded arguments or the inherited environment. They
    # can contain tokens even when the caller did not intend to log them.
    return {**plan.details, "runner_executable": plan.command[0],
            "working_directory": str(plan.cwd),
            "validation": "local files/options only; runner, login and games not executed"}


def write_report(path: Path, report: dict[str, object]) -> None:
    path = path.expanduser().absolute()
    # Exclusive creation prevents symlink following and accidental overwrites.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
        f.write("\n")


def main(argv: list[str] | None = None, *, default_exe: Path | None = None,
         expected_arch: str = "x64", description: str | None = None) -> int:
    raw = list(sys.argv[1:] if argv is None else argv)
    split = raw.index("--") if "--" in raw else len(raw)
    args = parser(default_exe, expected_arch, description).parse_args(raw[:split])
    forwarded = raw[split + 1:]
    try:
        plan = make_plan(args, forwarded)
        report = diagnostic_report(plan)
        if args.report:
            write_report(args.report, report)
        if args.diagnose or args.dry_run:
            print(json.dumps(report, indent=2, ensure_ascii=False))
            return 0
        print(f"Starting with {args.runner}. Close the application before changing its runtime/prefix.", flush=True)
        result = subprocess.run(plan.command, cwd=plan.cwd, env=plan.environment, check=False)
        if result.returncode:
            print(f"Runner exited with code {result.returncode}. For Proton, start the game once in Steam and check Protontricks is installed.", file=sys.stderr)
        return result.returncode if result.returncode >= 0 else 128 - result.returncode
    except (LaunchError, OSError) as exc:
        print(f"Compatibility launcher: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    if sys.version_info < (3, 10):
        print("Compatibility launcher requires Python 3.10 or newer.", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main())
