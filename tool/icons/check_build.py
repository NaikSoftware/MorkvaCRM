"""Self-check for build.glyph_path: overlapping shapes unite, knockouts stay.

    .venv/bin/python tool/icons/check_build.py
"""

import tempfile
from pathlib import Path

import build

CASES = {
    # Two 12x12 squares overlapping by 6x6, wound in opposite directions.
    "opposite_winding": (
        '<path fill="currentColor" d="M2 2H14V14H2Z"/>'
        '<path fill="currentColor" d="M8 8V20H20V8Z"/>',
        252,
    ),
    # One element with fill and stroke must stay solid (12x12 + 1u halo).
    "fill_and_stroke": (
        '<rect x="6" y="6" width="12" height="12" fill="currentColor" '
        'stroke="currentColor" stroke-width="2"/>',
        196,
    ),
    # An evenodd knockout keeps its hole: 16x16 minus 8x8.
    "evenodd_hole": (
        '<path fill="currentColor" fill-rule="evenodd" d="M4 4H20V20H4ZM8 8H16V16H8Z"/>',
        192,
    ),
}

with tempfile.TemporaryDirectory() as d:
    for name, (body, area) in CASES.items():
        f = Path(d) / f"{name}.svg"
        f.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">{body}</svg>')
        got = build.glyph_path(f).area
        assert abs(got - area) < 1, f"{name}: area {got}, want {area}"
        print(f"ok {name}: {got:.0f}")
