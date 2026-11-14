"""Rewrites Material `Icons.x` references in lib/ and test/ to `MorkvaIcons.y`
using column 2 of concepts.tsv. Idempotent: re-run after a rebase brings in new
Material icon uses. Prints the files it changed (format those, nothing else).

    python3 tool/icons/migrate.py
"""

import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
IMPORT = "import 'package:morkva_crm/design/morkva_icons.dart';"

mapping = {}
for line in (HERE / "concepts.tsv").read_text().splitlines():
    if line.strip():
        name, material = line.split("\t")[:2]
        for m in material.split(","):
            mapping[m] = name

ref = re.compile(r"(?<![A-Za-z0-9_$.])Icons\.([a-z0-9_]+)\b")
imports_icons = re.compile(r"^import '[^']*design/(design|morkva_icons)\.dart';", re.M)
last_import = re.compile(r"^import [^;]+;\n(?!import )", re.M)

unmapped = set()
for f in sorted([*ROOT.glob("lib/**/*.dart"), *ROOT.glob("test/**/*.dart")]):
    if f.name == "morkva_icons.dart":
        continue
    src = f.read_text()

    def sub(m):
        if m.group(1) in mapping:
            return f"MorkvaIcons.{mapping[m.group(1)]}"
        unmapped.add(f"{m.group(1)} ({f.relative_to(ROOT)})")
        return m.group(0)

    out = ref.sub(sub, src)
    if out == src:
        continue
    if not imports_icons.search(out):
        matches = list(last_import.finditer(out))
        at = matches[-1].end() if matches else 0
        out = out[:at] + IMPORT + "\n" + out[at:]
    f.write_text(out)
    print(f.relative_to(ROOT))

for u in sorted(unmapped):
    print(f"# left as Material: {u}")
