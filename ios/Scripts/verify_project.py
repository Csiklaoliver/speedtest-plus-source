#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "Makefile", "control", "SpeedtestPlus.plist", "README.md", "NOTICE.md",
    "Sources/Tweak.xm", "Sources/SPState.m", "Sources/SPCurve.m",
    "Sources/SPControlsViewController.m", "Sources/SPDiagnostics.m", "Sources/SPTheme.m",
    "Sources/SPShareBuilder.m", "Sources/SPUpdater.m", "Sources/SPMotion.m",
    "docs/HOOK_MAP.md", "docs/BUILD_AND_SIGN.md", "docs/REVIEW_CHECKLIST.md",
    "../docs/REDUCED_MOTION.md",
    "Scripts/inspect_ipa.py", "Scripts/package_review.py", "Scripts/verify_hook_map.py", "Scripts/verify_objc_syntax.py", "Tests/test_curve.py", "Tests/test_source_contract.py",
]
SECRET_PATTERNS = [
    re.compile(r"discord(?:app)?\.com/api/webhooks/", re.I),
    re.compile(r"BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY"),
    re.compile(r"[\"'](?:password|passwd)[\"']\s*[:=]\s*[\"'][^\"']+[\"']", re.I),
    re.compile(r"46\.224\.155\.10"),
]


def main() -> int:
    failures = []
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            failures.append(f"missing {relative}")
    for path in ROOT.rglob("*"):
        if not path.is_file() or "reference" in path.parts or path.suffix.lower() in {".ipa", ".dylib", ".deb"}:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for pattern in SECRET_PATTERNS:
            if pattern.search(text):
                failures.append(f"possible secret in {path.relative_to(ROOT)}: {pattern.pattern}")
        if "\u2014" in text:
            failures.append(f"em dash in {path.relative_to(ROOT)}")
    if failures:
        print("verification failed")
        print("\n".join(f"- {failure}" for failure in failures))
        return 1
    print(f"verification passed: {len(REQUIRED)} required files and no blocked secret patterns")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
