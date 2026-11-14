"""Builds the Morkva icon font from tool/icons/svg/*.svg.

Outputs assets/fonts/MorkvaIcons.ttf, lib/design/morkva_icons.dart and, with
--sheet, an HTML contact sheet that renders every glyph from the built font.

    python3 -m venv .venv && .venv/bin/pip install -r tool/icons/requirements.txt
    .venv/bin/python tool/icons/build.py [--sheet out.html] [--only a,b]

Sources are 24x24 SVGs drawn with strokes and/or fills; picosvg turns strokes
into outlines and skia-pathops unions them into one nonzero glyph, so what the
browser shows for the SVG is what Flutter draws from the font.
"""

import argparse
import json
import re
import sys
from pathlib import Path

import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path
from picosvg.svg import SVG

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
FAMILY = "MorkvaIcons"
UPEM = 1200
SCALE = UPEM / 24
FIRST_CODEPOINT = 0xE000


def load_concepts():
    concepts = []
    for line in (HERE / "concepts.tsv").read_text().splitlines():
        if not line.strip():
            continue
        name, material, meaning, flags = (line.split("\t") + [""])[:4]
        concepts.append(
            {
                "name": name,
                "material": material.split(","),
                "meaning": meaning,
                "flags": set(filter(None, flags.split(","))),
            }
        )
    return concepts


INK = {"none", "currentcolor", "black", "#000", "#000000"}
BANNED = re.compile(r"<(text|image|mask|clipPath|linearGradient|radialGradient|filter|use)\b"
                    r"|opacity\s*[=:]")
COLOR = re.compile(r"""(?:fill|stroke)\s*[=:]\s*["']?([^"';\s>]+)""")


def lint(svg_file):
    """The font is one ink colour: every shape is unioned, so a white shape
    meant to "erase" would print solid. Knock out with evenodd or real gaps."""
    src = svg_file.read_text()
    if m := BANNED.search(src):
        raise ValueError(f"{svg_file.name}: '{m.group(0)}' is not allowed")
    for colour in COLOR.findall(src):
        if colour.lower() not in INK:
            raise ValueError(f"{svg_file.name}: colour '{colour}' — use currentColor/none")


def glyph_path(svg_file):
    """Returns the union of every shape in [svg_file] as one pathops.Path."""
    lint(svg_file)
    pico = SVG.parse(str(svg_file)).topicosvg()
    vb = pico.view_box()
    if (vb.x, vb.y, vb.w, vb.h) != (0, 0, 24, 24):
        raise ValueError(f"{svg_file.name}: viewBox must be 0 0 24 24, got {vb}")
    parts = []
    for shape in pico.shapes():
        p = pathops.Path()
        parse_path(shape.d, p.getPen())
        if getattr(shape, "fill_rule", "nonzero") == "evenodd":
            p.fillType = pathops.FillType.EVEN_ODD
        if getattr(shape, "fill", "") in ("none",):
            continue
        parts.append(p)
    if not parts:
        raise ValueError(f"{svg_file.name}: no shapes")
    # Resolve each shape on its own fill rule, then fold real unions:
    # pathops.union() sums windings, so opposite-wound overlaps would cancel.
    out = pathops.Path()
    for p in parts:
        p.simplify(fix_winding=True)
        out = pathops.op(out, p, pathops.PathOp.UNION, fix_winding=True)
    x0, y0, x1, y1 = out.bounds
    if x0 < 0 or y0 < 0 or x1 > 24 or y1 > 24:
        raise ValueError(f"{svg_file.name}: ink {out.bounds} leaves the 0..24 box")
    if out.area < 1:
        raise ValueError(f"{svg_file.name}: glyph is empty")
    return out


def tt_glyph(path):
    pen = TTGlyphPen(None)
    # SVG is y-down in a 24 box; the font is y-up with the em box 0..UPEM.
    path.draw(TransformPen(Cu2QuPen(pen, max_err=1.0, reverse_direction=True),
                           (SCALE, 0, 0, -SCALE, 0, UPEM)))
    return pen.glyph()


def codepoints(names):
    cp_file = HERE / "codepoints.json"
    cps = json.loads(cp_file.read_text()) if cp_file.exists() else {}
    nxt = max(cps.values(), default=FIRST_CODEPOINT - 1) + 1
    for n in names:
        if n not in cps:
            cps[n] = nxt
            nxt += 1
    cp_file.write_text(json.dumps(cps, indent=2) + "\n")
    return cps


SVG_DIR = HERE / "svg"


def build_font(concepts, cps, out):
    names = [c["name"] for c in concepts]
    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder([".notdef"] + names)
    fb.setupCharacterMap({cps[n]: n for n in names})
    empty = TTGlyphPen(None).glyph()
    glyphs = {".notdef": empty}
    for n in names:
        glyphs[n] = tt_glyph(glyph_path(SVG_DIR / f"{n}.svg"))
    fb.setupGlyf(glyphs)
    # FreeType places each outline so xMin == lsb; lsb 0 would push every glyph flush left.
    glyf = fb.font["glyf"]
    for g in glyphs:
        glyf[g].recalcBounds(glyf)
    fb.setupHorizontalMetrics(
        {g: (UPEM, glyf[g].xMin if glyf[g].numberOfContours else 0) for g in glyphs})
    fb.setupHorizontalHeader(ascent=UPEM, descent=0)
    fb.setupNameTable({"familyName": FAMILY, "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=UPEM, sTypoDescender=0, sTypoLineGap=0,
                usWinAscent=UPEM, usWinDescent=0)
    fb.setupPost()
    out.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(out))


def build_dart(concepts, cps, out):
    lines = [
        "// GENERATED by tool/icons/build.py from tool/icons/svg — do not edit.",
        "",
        "import 'package:flutter/widgets.dart';",
        "",
        "/// MorkvaCRM's own icon set (font family `MorkvaIcons`), drawn on a 24 px",
        "/// grid. Use these instead of Material `Icons` everywhere in the app.",
        "abstract final class MorkvaIcons {",
        f"  static const String _family = '{FAMILY}';",
    ]
    for c in concepts:
        rtl = ", matchTextDirection: true" if "rtl" in c["flags"] else ""
        decl = (f"  static const IconData {c['name']} ="
                f" IconData(0x{cps[c['name']]:x}, fontFamily: _family{rtl});")
        if len(decl) > 80:  # the shape dart format gives a long call
            args = [f"0x{cps[c['name']]:x}", "fontFamily: _family", *(["matchTextDirection: true"] if rtl else [])]
            decl = (f"  static const IconData {c['name']} = IconData(\n"
                    + "".join(f"    {a},\n" for a in args) + "  );")
        lines += [
            "",
            f"  /// {c['meaning'].split(';')[-1].strip().capitalize()}.",
            decl,
        ]
    lines += [
        "",
        "  /// Every icon by name, for previews and tests.",
        "  static const Map<String, IconData> all = {",
        *[f"    '{c['name']}': {c['name']}," for c in concepts],
        "  };",
        "}",
        "",
    ]
    out.write_text("\n".join(lines))


def build_sheet(concepts, cps, font, out):
    cells = "".join(
        f'<figure><div class="g">'
        + "".join(f'<i style="font-size:{s}px">&#x{cps[c["name"]]:x};</i>' for s in (14, 16, 20, 24))
        + f'</div><i class="big">&#x{cps[c["name"]]:x};</i><figcaption>{c["name"]}</figcaption></figure>'
        for c in concepts
    )
    out.write_text(f"""<!doctype html><meta charset=utf-8><title>Morkva icons</title>
<style>
@font-face{{font-family:{FAMILY};src:url('{font.resolve().as_uri()}')}}
body{{margin:0;padding:16px;font:12px system-ui;display:grid;grid-template-columns:1fr 1fr;gap:16px}}
section{{display:grid;grid-template-columns:repeat(auto-fill,minmax(112px,1fr));gap:8px;padding:12px;border-radius:12px}}
.light{{background:#FBF7F2;color:#2B2018}} .dark{{background:#211913;color:#F3E9DD}}
figure{{margin:0;display:flex;flex-direction:column;align-items:center;gap:4px}}
i{{font-family:{FAMILY};font-style:normal;line-height:1}}
.g{{display:flex;gap:6px;align-items:end}} .big{{font-size:48px}}
figcaption{{opacity:.7}}
</style><section class=light>{cells}</section><section class=dark>{cells}</section>""")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", type=Path, help="also write an HTML contact sheet")
    ap.add_argument("--only", help="comma-separated names: build a scratch font/sheet "
                    "of just these, without touching the app files")
    ap.add_argument("--font", type=Path, help="font output path (default: app asset)")
    ap.add_argument("--svg-dir", type=Path, help="source dir (default: tool/icons/svg)")
    args = ap.parse_args()
    global SVG_DIR
    SVG_DIR = args.svg_dir or SVG_DIR

    concepts = load_concepts()
    if args.only:
        keep = args.only.split(",")
        concepts = [c for c in concepts if c["name"] in keep]
        missing = set(keep) - {c["name"] for c in concepts}
        if missing:
            sys.exit(f"unknown names: {sorted(missing)}")
        cps = {c["name"]: FIRST_CODEPOINT + i for i, c in enumerate(concepts)}
        font = args.font or Path(args.sheet).with_suffix(".ttf")
    else:
        missing = [c["name"] for c in concepts if not (SVG_DIR / f"{c['name']}.svg").exists()]
        if missing:
            sys.exit(f"missing svg for: {missing}")
        cps = codepoints([c["name"] for c in concepts])
        font = args.font or ROOT / "assets/fonts/MorkvaIcons.ttf"
        build_dart(concepts, cps, ROOT / "lib/design/morkva_icons.dart")

    build_font(concepts, cps, font)
    if args.sheet:
        build_sheet(concepts, cps, font, args.sheet)
    print(f"built {len(concepts)} glyphs -> {font}")


if __name__ == "__main__":
    main()
