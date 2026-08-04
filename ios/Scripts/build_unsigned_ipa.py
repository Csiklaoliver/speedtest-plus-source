#!/usr/bin/env python3
"""Build a clean unsigned review IPA from a decrypted Speedtest IPA.

The proprietary input IPA is never copied into the source tree or uploaded.
The output intentionally has no signing material and must be signed by the
reviewer before installation.
"""

from __future__ import annotations

import argparse
import hashlib
import plistlib
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

import lief


LEGACY_DYLIBS = {
    "Fixipa1.dylib",
    "ADsBlocker.dylib",
    "Fixipa2.dylib",
    "libsubstrate.dylib",
    "NoAds-AB.dylib",
    "GCDWebServer.dylib",
    "adblocker.dylib",
}
INJECTED_PATH = "@executable_path/Frameworks/SpeedtestPlus.dylib"


def app_prefix(entries: list[str]) -> str:
    apps = {
        "/".join(PurePosixPath(name).parts[:2]) + "/"
        for name in entries
        if len(PurePosixPath(name).parts) >= 2
        and PurePosixPath(name).parts[0] == "Payload"
        and PurePosixPath(name).parts[1].endswith(".app")
    }
    if len(apps) != 1:
        raise ValueError(f"expected one Payload app, found {sorted(apps)}")
    return apps.pop()


def patch_executable(source: bytes, output: Path) -> None:
    input_path = output.with_suffix(".input")
    input_path.write_bytes(source)
    fat = lief.MachO.parse(str(input_path))
    if fat is None or fat.size == 0:
        raise ValueError("main executable is not a readable Mach-O")
    for binary in fat:
        binary.remove_signature()
        for command in list(binary.libraries):
            if PurePosixPath(command.name).name in LEGACY_DYLIBS:
                if not binary.remove(command):
                    raise RuntimeError(f"could not remove {command.name}")
        if not any(command.name == INJECTED_PATH for command in binary.libraries):
            if binary.add_library(INJECTED_PATH) is None:
                raise RuntimeError("could not add SpeedtestPlus load command")
    fat.write(str(output))
    input_path.unlink()


def copy_info(source: zipfile.ZipInfo) -> zipfile.ZipInfo:
    target = zipfile.ZipInfo(source.filename, source.date_time)
    target.compress_type = source.compress_type
    target.comment = source.comment
    target.extra = source.extra
    target.create_system = source.create_system
    target.create_version = source.create_version
    target.extract_version = source.extract_version
    target.flag_bits = source.flag_bits
    target.internal_attr = source.internal_attr
    target.external_attr = source.external_attr
    return target


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--dylib", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    if args.input.resolve() == args.output.resolve():
        raise ValueError("output must not overwrite the reference IPA")
    if not args.input.is_file() or not args.dylib.is_file():
        raise FileNotFoundError("input IPA or compiled dylib is missing")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.input, "r") as source:
        names = source.namelist()
        prefix = app_prefix(names)
        plist_name = prefix + "Info.plist"
        plist = plistlib.loads(source.read(plist_name))
        executable_name = plist["CFBundleExecutable"]
        executable_path = prefix + executable_name
        dylib_path = prefix + "Frameworks/SpeedtestPlus.dylib"

        with tempfile.TemporaryDirectory(prefix="speedtestplus-ios-") as temp:
            patched_path = Path(temp) / executable_name
            patch_executable(source.read(executable_path), patched_path)
            patched = patched_path.read_bytes()

        plist["CFBundleDisplayName"] = "Speedtest+"
        plist["CFBundleName"] = "Speedtest+"
        plist["SpeedtestPlusVersion"] = "0.1.10"
        plist_data = plistlib.dumps(plist, fmt=plistlib.FMT_BINARY, sort_keys=False)

        with zipfile.ZipFile(args.output, "w", allowZip64=True) as target:
            for item in source.infolist():
                relative = item.filename[len(prefix):] if item.filename.startswith(prefix) else ""
                leaf = PurePosixPath(item.filename).name
                if item.filename == executable_path or item.filename == plist_name:
                    continue
                if item.filename.startswith(prefix + "_CodeSignature/"):
                    continue
                if item.filename == prefix + "embedded.mobileprovision":
                    continue
                # A previously patched reference may already contain our
                # dylib. Never copy it through or the output would contain
                # duplicate Frameworks/SpeedtestPlus.dylib entries.
                if item.filename == dylib_path:
                    continue
                if relative and leaf in LEGACY_DYLIBS and "/" not in relative:
                    continue
                target.writestr(copy_info(item), source.read(item.filename))

            executable_info = copy_info(source.getinfo(executable_path))
            target.writestr(executable_info, patched)
            plist_info = copy_info(source.getinfo(plist_name))
            target.writestr(plist_info, plist_data)

            dylib_info = zipfile.ZipInfo(dylib_path)
            dylib_info.compress_type = zipfile.ZIP_DEFLATED
            dylib_info.create_system = 3
            dylib_info.external_attr = 0o100755 << 16
            target.writestr(dylib_info, args.dylib.read_bytes())

    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    print(f"created {args.output.resolve()}")
    print(f"sha256 {digest}")
    print("status unsigned; reviewer must sign before installation")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
