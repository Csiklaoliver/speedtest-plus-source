#!/usr/bin/env python3
"""Inspect an IPA or extracted .app without modifying it.

The report is intentionally limited to compatibility metadata required by the
independently written Speedtest+ hook layer.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import struct
import tempfile
import zipfile
from pathlib import Path

import lief


def coredata_speedtest_fields(app: Path) -> dict[str, dict[str, object]]:
    model_dir = app / "Frameworks" / "SpeedTestEngine.framework" / "SpeedTestEngineModels.bundle" / "SpeedTestModel.momd"
    version_file = model_dir / "VersionInfo.plist"
    if not version_file.exists():
        return {}
    version_info = plistlib.loads(version_file.read_bytes())
    version = version_info.get("NSManagedObjectModel_CurrentVersionName")
    model_file = model_dir / f"{version}.mom"
    archive = plistlib.loads(model_file.read_bytes())
    objects = archive["$objects"]

    def dereference(value):
        return objects[value.data] if isinstance(value, plistlib.UID) else value

    entity_name_index = next((index for index, value in enumerate(objects) if value == "SpeedTestResult"), None)
    if entity_name_index is None:
        return {}
    entity = next((value for value in objects if isinstance(value, dict) and isinstance(value.get("NSEntityName"), plistlib.UID) and value["NSEntityName"].data == entity_name_index), None)
    if not entity:
        return {}
    properties = dereference(entity["NSProperties"])
    result = {}
    for key_uid, value_uid in zip(properties["NS.keys"], properties["NS.objects"]):
        name = dereference(key_uid)
        attribute = dereference(value_uid)
        if not isinstance(attribute, dict) or "NSAttributeType" not in attribute:
            continue
        result[name] = {
            "attribute_type": dereference(attribute.get("NSAttributeType")),
            "value_class": dereference(attribute.get("NSAttributeValueClassName")),
        }
    return result


INTERESTING_CLASSES = {
    "_TtC9SpeedTest23SpeedTestViewController",
    "_TtC9SpeedTest27ResultDetailsViewController",
    "_TtC9SpeedTest30PreparedFeedbackViewController",
    "_TtC9SpeedTest24ResultListViewController",
    "_TtC9SpeedTest26SelectServerViewController",
    "_TtC9SpeedTest33CompareResultsOfferViewController",
    "_TtC9SpeedTest28SpeedtestCardsViewController",
    "_TtC5Gauge22GaugeViewControlleriOS",
    "_TtC5Gauge17ISPHostController",
    "TestParameters",
    "TestParametersTransfer",
    "TestParametersLatency",
    "ResultReport",
    "ResultReportBuilder",
    "ResultSaver",
    "ReportPacketLossModel",
    "CoreDataManager",
    "GraphSampleEntryModel",
    "GraphSamplesModel",
    "CFCSurveyViewStateSurveyAsked",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def locate_app(source: Path, temp: Path) -> tuple[Path, str | None]:
    if source.suffix.lower() == ".ipa":
        with zipfile.ZipFile(source) as archive:
            members = [name for name in archive.namelist() if name.startswith("Payload/")]
            archive.extractall(temp, members)
        apps = list((temp / "Payload").glob("*.app"))
        if len(apps) != 1:
            raise RuntimeError(f"expected one app in IPA, found {len(apps)}")
        return apps[0], sha256(source)
    if source.suffix == ".app" and source.is_dir():
        return source, None
    raise RuntimeError("input must be an IPA or extracted .app directory")


class ObjCReader:
    def __init__(self, binary):
        self.binary = binary
        self.base = int(binary.imagebase)

    def bytes(self, address: int, size: int) -> bytes:
        return bytes(self.binary.get_content_from_virtual_address(address, size))

    def u32(self, address: int) -> int:
        return struct.unpack("<I", self.bytes(address, 4))[0]

    def i32(self, address: int) -> int:
        return struct.unpack("<i", self.bytes(address, 4))[0]

    def u64(self, address: int) -> int:
        return struct.unpack("<Q", self.bytes(address, 8))[0]

    def pointer(self, raw: int) -> int:
        if self.base <= raw < self.base + 0x100000000:
            return raw
        if raw == 0:
            return 0
        return self.base + (raw & 0xFFFFFFFFF)

    def cstring(self, address: int, limit: int = 1024) -> str:
        data = self.bytes(address, limit)
        return data.split(b"\0", 1)[0].decode("utf-8", "replace")

    def methods(self, address: int) -> list[dict[str, str]]:
        if not address:
            return []
        flags = self.u32(address)
        count = min(self.u32(address + 4), 4096)
        relative = bool(flags & 0x80000000)
        direct = bool(flags & 0x40000000)
        entry_size = flags & 0xFFFF
        if entry_size < (12 if relative else 24):
            entry_size = 12 if relative else 24
        entries = []
        for index in range(count):
            entry = address + 8 + index * entry_size
            try:
                if relative:
                    name_target = entry + self.i32(entry)
                    if not direct:
                        name_target = self.pointer(self.u64(name_target))
                    types_target = entry + 4 + self.i32(entry + 4)
                    implementation = entry + 8 + self.i32(entry + 8)
                else:
                    name_target = self.pointer(self.u64(entry))
                    types_target = self.pointer(self.u64(entry + 8))
                    implementation = self.pointer(self.u64(entry + 16))
                entries.append({"selector": self.cstring(name_target), "types": self.cstring(types_target), "implementation": hex(implementation)})
            except Exception:
                continue
        return entries

    def classes(self) -> dict[str, list[dict[str, str]]]:
        section = next((item for item in self.binary.sections if item.name == "__objc_classlist"), None)
        if section is None:
            return {}
        result = {}
        content = bytes(section.content)
        for offset in range(0, len(content), 8):
            try:
                class_address = self.pointer(struct.unpack_from("<Q", content, offset)[0])
                data_bits = self.pointer(self.u64(class_address + 32)) & ~0x7
                name_address = self.pointer(self.u64(data_bits + 24))
                methods_address = self.pointer(self.u64(data_bits + 32))
                name = self.cstring(name_address)
                if name:
                    methods = self.methods(methods_address)
                    meta_address = self.pointer(self.u64(class_address))
                    if meta_address:
                        meta_data = self.pointer(self.u64(meta_address + 32)) & ~0x7
                        meta_methods = self.pointer(self.u64(meta_data + 32))
                        for method in self.methods(meta_methods):
                            method["class_method"] = True
                            methods.append(method)
                    result[name] = methods
            except Exception:
                continue
        return result


def inspect(source: Path) -> dict:
    with tempfile.TemporaryDirectory(prefix="speedtestplus-inspect-") as temporary:
        app, ipa_hash = locate_app(source.resolve(), Path(temporary))
        with (app / "Info.plist").open("rb") as handle:
            info = plistlib.load(handle)
        executable = app / info["CFBundleExecutable"]
        binary = lief.parse(str(executable))
        classes = ObjCReader(binary).classes()
        encryption = next((command for command in binary.commands if hasattr(command, "crypt_id")), None)
        libraries = [command.name for command in binary.libraries]
        selected = {
            name: methods for name, methods in sorted(classes.items())
            if name in INTERESTING_CLASSES or any(token in name for token in ("SharingTextActivityItem", "SharingResultsCSVTextActivityItem"))
        }
        framework_classes = {}
        for framework_name in ("Gauge", "SpeedTestEngine", "cardsFrameworkCore"):
            framework_binary = app / "Frameworks" / f"{framework_name}.framework" / framework_name
            if not framework_binary.exists():
                continue
            parsed_framework = lief.parse(str(framework_binary))
            runtime = ObjCReader(parsed_framework).classes()
            framework_classes[framework_name] = {
                name: methods for name, methods in sorted(runtime.items())
                if name in INTERESTING_CLASSES
            }
        return {
            "source": str(source.resolve()),
            "ipa_sha256": ipa_hash,
            "bundle_id": info.get("CFBundleIdentifier"),
            "display_name": info.get("CFBundleDisplayName") or info.get("CFBundleName"),
            "version": info.get("CFBundleShortVersionString"),
            "build": info.get("CFBundleVersion"),
            "minimum_ios": info.get("MinimumOSVersion"),
            "executable": executable.name,
            "executable_sha256": sha256(executable),
            "encrypted": None if encryption is None else bool(encryption.crypt_id),
            "framework_count": len(list((app / "Frameworks").glob("*.framework"))),
            "embedded_provision": (app / "embedded.mobileprovision").exists(),
            "executable_relative_libraries": [name for name in libraries if name.startswith("@executable_path/")],
            "objc_class_count": len(classes),
            "selected_runtime_classes": selected,
            "selected_framework_runtime_classes": framework_classes,
            "speedtest_result_coredata_fields": coredata_speedtest_fields(app),
        }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = inspect(args.input)
    rendered = json.dumps(report, indent=2, sort_keys=True)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    else:
        print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
