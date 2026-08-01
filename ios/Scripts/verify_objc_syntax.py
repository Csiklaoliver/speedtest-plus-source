#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from tree_sitter_language_pack import get_parser


ROOT = Path(__file__).resolve().parents[1]


def errors(node):
    found = []
    if node.type == "ERROR" or node.is_missing:
        found.append(node)
    for child in node.children:
        found.extend(errors(child))
    return found


def main() -> int:
    parser = get_parser("objc")
    failures = []
    # The bundled Objective-C grammar does not understand Apple's modern
    # nullability and lightweight-generic declarations in headers. Parse every
    # implementation unit, which still covers all executable code and local
    # private interfaces.
    files = sorted((ROOT / "Sources").glob("*.m")) + [ROOT / "Sources" / "Tweak.xm"]
    for path in files:
        source = path.read_bytes()
        tree = parser.parse(source)
        for node in errors(tree.root_node):
            row, column = node.start_point
            snippet = source[node.start_byte:node.end_byte][:100].decode("utf-8", "replace").replace("\n", " ")
            failures.append(f"{path.name}:{row + 1}:{column + 1}: {node.type} {snippet}")
    if failures:
        print("Objective-C syntax verification failed")
        print("\n".join(f"- {failure}" for failure in failures))
        return 1
    print(f"Objective-C syntax verification passed: {len(files)} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
