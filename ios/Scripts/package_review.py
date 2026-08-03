#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXCLUDED_PARTS = {"reference", "build", ".theos", "packages", ".git", "__pycache__"}
EXCLUDED_SUFFIXES = {".ipa", ".deb", ".dylib", ".mobileprovision", ".p12", ".cer"}


def included(path: Path) -> bool:
    relative = path.relative_to(ROOT)
    return not any(part in EXCLUDED_PARTS for part in relative.parts) and path.suffix.lower() not in EXCLUDED_SUFFIXES


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "build" / "SpeedtestPlus-iOS-review-source.zip")
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    files = sorted(path for path in ROOT.rglob("*") if path.is_file() and included(path) and path.resolve() != output)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            archive.write(path, Path("SpeedtestPlus-iOS") / path.relative_to(ROOT))
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(f"created {output}")
    print(f"files {len(files)}")
    print(f"sha256 {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

