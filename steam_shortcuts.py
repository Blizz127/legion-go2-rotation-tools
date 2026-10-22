#!/usr/bin/env python3
"""Add or update non-Steam shortcuts in Steam's shortcuts.vdf (binary VDF).

Steam must be closed while this runs; it rewrites the file on exit and only
reads it on start. Entries are matched by app name, so re-running updates in
place. Pure standard library: no `vdf` package needed on the target device.

    python3 steam_shortcuts.py --steam ~/.local/share/Steam add \
        --name "AION 2 Cleric Rotation (Y1)" --exe /path/launch.sh --dir /path \
        [--icon /path/icon.png] [--tag Rotation]
    python3 steam_shortcuts.py --steam ~/.local/share/Steam list
"""

from __future__ import annotations

import argparse
import shutil
import sys
import time
import zlib
from pathlib import Path

_MAP, _STR, _INT, _END = 0x00, 0x01, 0x02, 0x08


def loads(data: bytes) -> dict:
    pos = 0

    def read_cstring() -> str:
        nonlocal pos
        end = data.index(b"\0", pos)
        value = data[pos:end].decode("utf-8", "replace")
        pos = end + 1
        return value

    def read_map() -> dict:
        nonlocal pos
        out: dict = {}
        while True:
            kind = data[pos]
            pos += 1
            if kind == _END:
                return out
            key = read_cstring()
            if kind == _MAP:
                out[key] = read_map()
            elif kind == _STR:
                out[key] = read_cstring()
            elif kind == _INT:
                out[key] = int.from_bytes(data[pos:pos + 4], "little", signed=True)
                pos += 4
            else:
                raise ValueError(f"unsupported binary VDF type {kind:#x} at {pos}")

    return read_map()


def dumps(obj: dict) -> bytes:
    out = bytearray()

    def write_map(mapping: dict) -> None:
        for key, value in mapping.items():
            if isinstance(value, dict):
                out.append(_MAP)
                out.extend(key.encode() + b"\0")
                write_map(value)
            elif isinstance(value, bool):
                out.append(_INT)
                out.extend(key.encode() + b"\0" + int(value).to_bytes(4, "little"))
            elif isinstance(value, int):
                out.append(_INT)
                out.extend(key.encode() + b"\0" + value.to_bytes(4, "little", signed=True))
            else:
                out.append(_STR)
                out.extend(key.encode() + b"\0" + str(value).encode() + b"\0")
        out.append(_END)

    write_map(obj)
    return bytes(out)


def shortcut_appid(exe: str, name: str) -> int:
    """Steam's non-Steam app id: crc32(exe + name) with the top bit set."""
    return (zlib.crc32((exe + name).encode()) | 0x80000000) & 0xFFFFFFFF


def _signed(value: int) -> int:
    return value - (1 << 32) if value >= 1 << 31 else value


def userdata_configs(steam: Path) -> list[Path]:
    return sorted(p for p in (steam / "userdata").glob("*/config") if p.parent.name != "0")


def load_shortcuts(path: Path) -> dict:
    if not path.exists():
        return {"shortcuts": {}}
    return loads(path.read_bytes())


def upsert(shortcuts: dict, *, name: str, exe: str, start_dir: str, icon: str,
           tags: list[str]) -> str:
    entries = shortcuts.setdefault("shortcuts", {})
    quoted_exe = f'"{exe}"'
    quoted_dir = f'"{start_dir}"'
    for index, entry in entries.items():
        if str(entry.get("AppName", entry.get("appname", ""))) == name:
            entry.update({
                "Exe": quoted_exe, "StartDir": quoted_dir, "icon": icon,
                "LaunchOptions": entry.get("LaunchOptions", ""),
                "tags": {str(i): t for i, t in enumerate(tags)},
            })
            entry["appid"] = _signed(shortcut_appid(quoted_exe, name))
            return "updated"
    index = str(max([int(k) for k in entries] + [-1]) + 1)
    appid = shortcut_appid(quoted_exe, name)
    entries[index] = {
        "appid": _signed(appid),
        "AppName": name,
        "Exe": quoted_exe,
        "StartDir": quoted_dir,
        "icon": icon,
        "ShortcutPath": "",
        "LaunchOptions": "",
        "IsHidden": 0,
        "AllowDesktopConfig": 1,
        "AllowOverlay": 1,
        "OpenVR": 0,
        "Devkit": 0,
        "DevkitGameID": "",
        "DevkitOverrideAppID": 0,
        "LastPlayTime": 0,
        "FlatpakAppID": "",
        "tags": {str(i): t for i, t in enumerate(tags)},
    }
    return "added"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--steam", type=Path, default=Path.home() / ".local/share/Steam")
    sub = parser.add_subparsers(dest="cmd", required=True)
    add = sub.add_parser("add", help="add or update one shortcut in every user config")
    add.add_argument("--name", required=True)
    add.add_argument("--exe", required=True)
    add.add_argument("--dir", required=True)
    add.add_argument("--icon", default="")
    add.add_argument("--tag", action="append", default=[])
    sub.add_parser("list", help="print existing shortcuts")
    args = parser.parse_args()

    configs = userdata_configs(args.steam)
    if not configs:
        sys.exit(f"no Steam user config under {args.steam}/userdata")
    for config in configs:
        path = config / "shortcuts.vdf"
        data = load_shortcuts(path)
        if args.cmd == "list":
            print(f"{path}:")
            for index, entry in data.get("shortcuts", {}).items():
                print(f"  [{index}] {entry.get('AppName', entry.get('appname'))} -> {entry.get('Exe', entry.get('exe'))}")
            continue
        if path.exists():
            backup = path.with_name(f"shortcuts.vdf.bak-{time.strftime('%Y%m%dT%H%M%S')}")
            shutil.copy2(path, backup)
        result = upsert(data, name=args.name, exe=args.exe, start_dir=args.dir,
                        icon=args.icon, tags=args.tag)
        path.write_bytes(dumps(data))
        print(f"{result}: {args.name} in {path}")


if __name__ == "__main__":
    main()
