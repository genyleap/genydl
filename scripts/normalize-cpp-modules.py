#!/usr/bin/env python3
"""Normalize Qt moc include guards for Clang dependency scanning.

CMake/clang-scan-deps must see `export module` and `import` outside
preprocessor conditionals. Qt moc still gets qtmochelpers under !Q_MOC_RUN.
Idempotent: --check exits nonzero if normalization is needed.
"""
from pathlib import Path
import argparse
import re

ROOT = Path(__file__).resolve().parent.parent
PATTERN = re.compile(
    r"(?m)^#ifndef Q_MOC_RUN\n"
    r"(?P<includes>(?:#\s*include[^\n]+\n)+)"
    r"(?P<module>export module [^;\n]+;\n)"
    r"(?P<imports>(?:import [^;\n]+;\n)*)"
    r"#endif\n"
)

SIMPLE = re.compile(r"(?m)^#ifndef Q_MOC_RUN\n(export module [^;\n]+;\n)#endif\n")

def normalize(source):
    source = SIMPLE.sub(lambda m: m[1], source)
    return PATTERN.sub(
        lambda m: "#ifndef Q_MOC_RUN\n" + m["includes"] + "#endif\n"
                  + m["module"] + m["imports"],
        source,
    )

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    changed = []
    for path in sorted((ROOT / "src").rglob("*.cppm")):
        original = path.read_text(encoding="utf-8")
        normalized = normalize(original)
        if original != normalized:
            changed.append(path.relative_to(ROOT).as_posix())
            if args.apply:
                path.write_text(normalized, encoding="utf-8")
    print(f"{len(changed)} module interfaces need normalization")
    for name in changed:
        print(" -", name)
    if changed and not args.apply:
        raise SystemExit(1)
