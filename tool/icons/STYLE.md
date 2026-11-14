# Morkva icons: Bricolage Ink-Trap style guide

This guide is binding for every glyph in `svg/`. The 14 shipped probes in `svg/` are the reference
drawings. When this text and a probe disagree, the probe wins and this text gets fixed.

**The idea.** Each icon is drawn the way a grotesque typeface draws its letters, so it sits next to
Bricolage Grotesque and Hanken Grotesk as if it were set in the same type.

- Vertical strokes are heavy and horizontal strokes are hairlines.
- Every terminal is cut flat.
- Tight joins get ink traps.

Every set we compete with (Lucide, Feather, Tabler, Phosphor, Heroicons, Material Symbols) uses an
even stroke weight. Most of them also use round caps. At 14 px our cue is **stroke contrast plus
square cuts**. From 20 px up, the ink traps become visible too.

## 1. Grid

| Item | Value |
|---|---|
| viewBox | `0 0 24 24`. 1u is one unit, which is 0.583 px at 14 px and 0.667 px at 16 px. |
| Live area | 2..22 on both axes. The generator (`gen.py`) refuses ink outside 1.75..22.25; `build.py` itself only rejects ink outside 0..24. |
| Overshoot | Pointed glyphs only (bolt, sparkle, star tips) may use 1.5..22.5. |
| Badge quadrant | 13..22 × 13..22, bottom right. |
| Edge snapping | Put stem and frame outer edges on the 0.25 grid, and prefer .0 or .5 (frames 2.5..21.5, stems 10.625..13.375 centred on 12). |
| Optical centre | Centre symmetric glyphs on x = 12. Badge glyphs move the base up and left (filterOff's axis is x = 9.625). |

## 2. Stroke: axis contrast

| Direction (θ from horizontal) | Width |
|---|---|
| Vertical, 90° | **V = 2.75u** (1.6 px at 14) |
| Horizontal, 0° | **H = 1.75u** (1.02 px at 14). Never thinner outside a trap. |
| Diagonal | `w = 1.75 + 1.0·|sin θ|`. 30° gives 2.25, 45° gives 2.46 and 60° gives 2.62. |
| Curves and rings | The outer ellipse is rx = r + V/2, ry = r + H/2, and the inner one is rx = r − V/2, ry = r − H/2. The ring is thick at 3 and 9 o'clock and thin at 12 and 6, like a grotesque "o". |

- Horizontals stay at 1.75u. The judges found that 1.02 px is already the faintest ink on espresso, so contrast was gained by widening V from 2.5 to 2.75, not by thinning H.
- Glyphs that are mostly horizontal strokes (notes, viewList, tableRows, menu-like rows) look grey next to glyphs that are mostly vertical. Give them **a vertical anchor**: a V-weight frame wall, solid bullets, or a stem. Never build a glyph from hairlines only.

## 3. Terminals, joins and corners

- **Butt terminals only.** Never use round caps.
  - Horizontal and vertical strokes are cut square.
  - Diagonals are cut **horizontally**, the way a grotesque cuts "v" and "w". A 45° stroke therefore reaches 1.74u past its endpoint along x. Allow for this against the live area.
  - **Exception:** both strokes of an "x" mark are cut square to the stroke. With horizontal cuts a small x reads as a bow-tie or hourglass (tested on searchOff).
  - Arc ends are cut radially.
- **Joins** are mitred, with a limit of 3. Chevrons, arrowheads and the check have sharp apexes.
- **Container corners:** r1.5 on the outside edge and square inside. This gives the tight corner of a grotesque letter.

| Element size | Outer radius |
|---|---|
| Containers 12u or larger (frames, pages, cards) | 1.5 |
| Small solids 4–8u (cards, columns, stop square) | 1 |
| Dots, texture dots and day dots | 0.5. These are near-square "full stops", never circles. |
| Stems, bars and rails | 0 |

## 4. Ink traps (the signature)

An ink trap is a triangular notch cut into the **joining** stroke from the counter side, so the join narrows.

| Where | Trap |
|---|---|
| T-junction: a stem meets a bar (calendar binding stems, header bar into walls, trash knob) | A notch on each side of the joining stroke, 25% of its width deep and 1.5–2.25u long. The neck is ≥ 50% of the stroke. |
| Crossing, "+" | The hairline arm pinches where it meets the stem, with a neck of 0.9u over 2.25u. The stem stays whole. |
| Acute or right interior join (90° or less): chevron apex, check vertex, clock-hands corner | An inner-side notch about 30–45% deep and 1.2–1.6u long. |
| Re-entrant corner of a solid (bolt waist) | A notch 1.0u deep and 1.2u long. |
| Stroke leaving a ring (search handle) | Both sides pinch over 2.25u. |

**Never put a trap on:**
- obtuse joins (more than 90°), for example the truck cab slope, because it reads as a chip;
- an outer L-corner of a container;
- curves;
- the edge of a filled disc or plate, because a nick there reads as "partial" or "damaged";
- the brand sparkle;
- any stroke shorter than 2× the trap length;
- anywhere the neck would drop below 0.9u.

At 14–16 px the traps only lighten joins, which stops T-junctions clogging. That is their job at
that size. Do not enlarge them to make them visible at 14 px.

## 5. Fill policy

- The default is an **outline in contrast strokes**.
- A closed sub-shape whose counter would be under 2.5u is drawn **solid**. Examples are the funnel stem, the truck cab when it is narrow, cards in layout glyphs, and wheels.
- Unset twins are contrast outlines: radioOff, checkCircle, pin, star.
- Filled twins (checkCircleFilled, pinFilled) are solid. The mark is knocked out and keeps its own contrast, its horizontal cuts and its traps. A trap in a knocked-out mark becomes a wedge of ink, which is correct.
- The brand sparkle is the `SparkleIcon` path **verbatim**, solid (`lib/features/assistant/view/widgets/sparkle_icon.dart`). Any other sparkle (autoMode, smartButton) is that path scaled. Never redraw it.
- A glyph may mix outline and solid parts. Keep its ink roughly even with its neighbours, and do not leave a large solid slab: split anything over about 6×10u solid into cards with gaps.

## 6. Legibility at 14 px (hard limits)

| Rule | Minimum |
|---|---|
| Gap between separate pieces of ink | **2u** (1.17 px). Wheels to chassis, box to cab, rail to cards, card to card. |
| Counter | **2.5u** in its smallest direction. Below that, go solid. |
| Gap between parallel hairlines | 2.25u edge to edge. Use at most 3 hairlines in a glyph. |
| Texture dots (calendar grid only) | 2.25u dots with 1.6u gaps are allowed. At 14 px they are meant to merge into a "grid" texture. |
| Off-slash clearance | 1.5u on each side. This is the only place a gap below 2u is allowed. |
| Mark in a badge | Half-size 2.75u (filterOff ships at 2.75); never below 2.5u. At 2.25u the x blurred into a dot at 14 px. |
| Text lines in a page | At most 2, with ≥ 2.25u gap. The second line is shorter. |

Check every glyph in the sheet at 14 and 16 px on cream **and** on espresso (see §10) before it counts as drawn.

## 7. Standard treatments

**Rendered or not.** These treatments were drawn and checked at 14–48 px: the off-slash (cloudOff), the x badge (filterOff), the x inside the lens (searchOff), calendars, clocks (history, update, schedule), the receipt page, people, viewBoard and chevrons. These are **specified but never rendered**: dog-ear pages, circle-enclosed glyphs, straight arrows, groups, sync, refresh, autoMode, table and viewColumns. Treat their numbers as a starting point, and correct this guide when the first drawing of each disagrees.

**Off / disabled.** Use a `\` slash from (4.25, 4.25) to (19.75, 19.75), 2.46u wide with horizontal cuts. Cut the base back 1.5u on both sides of the slash as real geometry. Butt edges, no rounded cut-ends.
- **Test first:** if any main stroke of the base runs within 20° of `\` and within 3u of the slash centreline, do not slash it. That stroke would vanish (the funnel's left wall, the search handle). Use the remove badge instead.
- Use the slash for cloudOff, timerOff, extensionOff and block. wifiOff, linkOff and colorReset take the x badge: the slash erased their bases (colorReset's drop flank runs within ~11° of it and read as stripes).
- Use the x badge for filterOff and hourglassOff (the hourglass sides run along both diagonals, so it fails the test).
- The concept list asks for "funnel with slash"; filterOff ships with the x badge because the slash failed the test. A funnel with a corner x is also how some stock sets draw filter-x, so the contrast strokes and cuts carry the difference.
- searchOff puts the x **inside the lens counter**, square-cut, with ≥ 1.5u clearance, because the handle already fills the badge quadrant.

**Badges (+, x, !, check)** go in the badge quadrant with no plate.
- The mark is centred at about (17.5, 17.5) with half-size 2.75 (minimum 2.5).
- The base is cut back with an r1 box 2u clear of the mark's ink.
- "+" uses a V-weight vertical and an H-weight horizontal. "x" uses two square-cut 2.46u diagonals.
- Move the base up and left so the cut takes only a corner (bookmarkAdd, uploadFile, deleteForever, syncProblem).

**Circle-enclosed glyphs** (addCircle, cancel, removeCircle, info, help, error, checkCircle, pauseCircle, stopCircle, dropdownField):
- The contrast ring is centred at (12, 12) with r = 8.5. That puts the outer edge at 2.125..21.875 horizontally and 2.625..21.375 vertically.
- The inner mark is at most 8u across, with ≥ 2u clearance to the ring.
- Filled twins use a solid disc of r 10 with the mark knocked out.

**Documents and pages** (file, description, uploadFile, stickyNote, receipt, copy):
- The page is a frame about 14u wide (x 5..19), with V side walls, H top and bottom, and r1.5 outer corners.
- The dog-ear is a 5u diagonal cut at the top right, drawn as a 45° contrast stroke with a solid triangle under it, since its counter is under 2.5u.
- Text lines follow §6.

**Calendars:**
- The frame is (2.5, 4.5)–(21.5, 21.75).
- Two V binding stems are centred at x = 9.125 and x = 14.875, at y 2..6. They have T-traps where they enter the top wall.
- An H header bar sits at y 8.5..10.25 with one-sided traps underneath.
- The body is what tells the members apart (§9).

**Clocks:**
- The ring is centred at (12, 12) with r 8.5. Arrow clocks are centred at (12, 12.5) with r 8.
- The hands are a single L, from the centre up 3.25–4.25u and right 3.25–3.5u, with a trap at the corner. They **always point to 12 and 3, even in mirrored glyphs**.
- Arrow arcs keep the gap at 12 o'clock.
- The arrowhead is a solid mitred triangle, 4.25u long, sitting at the end of the arc and pointing along the direction of travel. Its base is asymmetric: 3.75u outward and 2.5u inward from the arc centreline, so its inner corner stays ≥ 2u from the hands.

**View layouts** (viewBoard, viewColumns, table, tableRows, gridView, mosaic, dashboard, spaceDashboard, viewList, viewCards, cards, barChart):
- Cells are **solid r1 cards with 2u gaps**, or a frame with dividers. Never use solid slabs taller than about 10u.
- At most 3 columns and at most 4 rows of anything.
- Dividers inside frames meet the walls at T-junctions with traps.
- Crossing dividers (table) are an exception: they cross like "+", with the hairline pinched.

**Arrows and chevrons:**
- A chevron is a mitred two-segment polyline with horizontal-cut ends and an inner trap at the apex. It is 15.5u tall and its angle is 90°.
- An arrow is a V or H shaft plus a chevron head. The shaft butts into the apex.
- Use the contrast rule for width, so vertical arrows are heavier than horizontal ones. That is intended.
- Glyphs flagged `rtl` must be mirror-safe: no text-like asymmetry other than the direction.

**People:**
- The head is a contrast ring centred at (12, 7) with r 3.75.
- The shoulders are a contrast half-ellipse arc centred at (12, 21.25), rx 7, ry 6.25, from 180° to 360°, with radial cuts.
- Leave a 2.5u gap between head and shoulders. The two pieces float and never touch.
- groups puts two smaller busts behind the front one, each clipped 2u clear of it.

## 8. Signature placement summary

| Signature element | Appears | Must not appear |
|---|---|---|
| V/H contrast | every stroke in every glyph | the solid sparkle, solid dots |
| Square/horizontal cuts | every terminal | anywhere as round caps or round joins |
| Ink traps | T-junctions, crossings, joins ≤ 90°, re-entrant solid corners | see the never list in §4 |
| r1.5 outer / square inner | containers | stems, bars, chevrons |

## 9. Confusable sets

| Set | How they differ |
|---|---|
| **history / update / schedule** | All share the clock face and the 12-to-3 hands. **schedule** is a closed ring with no arrow. **history** has an arc open at 12 o'clock and a head at 1 o'clock pointing left (counter-clockwise). **update** has the arc mirrored, with its head at 11 o'clock pointing right. The hands are not mirrored. |
| **calendarDay / calendarMonth / event / eventBusy** | All share the calendar frame, stems and header. **calendarDay** has an empty body. **calendarMonth** has a 2×3 grid of 2.25u dots, which reads as texture at 14 px. **event** has one solid r1 5u square at the bottom right (x 13..18, y 13..18). **eventBusy** has an x badge with the frame's bottom-right corner cut back. |
| **viewBoard / viewColumns / table / tableRows** | **viewBoard** is the only one with a hairline rail and no frame: ragged solid cards hang in three columns. **viewColumns** is a frame with two full-height V dividers and equal columns. **table** is a frame with an H header bar plus one V and one H divider, using T-traps and a "+" crossing. **tableRows** is a frame with two H dividers and no verticals. |
| **file / description / uploadFile / stickyNote** | **file** is the dog-eared page with an empty body. **description** is the same page with 2 text lines. **uploadFile** is the page moved up and left, with an up arrow in the badge quadrant and the corner cut 2u clear. **stickyNote** is a square (16×16) with the dog-ear at the **bottom right** instead of the top right. |
| **block / cancel / removeCircle** | All three use the same r 8.5 ring. **block** has the `\` slash through it, and the slash runs to the ring with no gap. **cancel** has a square-cut x inside, half-size 3.25. **removeCircle** has a single H-weight hairline bar inside (x 7.5..16.5), the only member with a horizontal mark. |
| **refresh / sync / autoMode** | **refresh** is one clockwise arrow arc with the gap at 12 and nothing inside. **sync** is two half-arcs with heads at 1 and 7 o'clock and gaps at 12 and 6. **autoMode** is the refresh arc (r 6.75 about (10.25, 13.25)) with an empty counter, plus the brand sparkle's large star (scaled to 6.5u, solid) outside the ring at the top right, about (19, 5) and ≥ 2u clear. A star in the centre collapsed to a dot at 14 px and read as update. **syncProblem** is the sync pair (r 6.75 about (10.25, 10.25)) with a badge "!" at the bottom right and the arcs cut 2u clear. |

## 10. Authoring, building and checking

- **Output:** one `<path fill="currentColor" d="…"/>` per file is preferred. Pre-union the glyph, as the reference generator does.
- `build.py` currently merges elements with `pathops.union`, which **sums windings**. Overlapping shapes with opposite winding cancel into holes, and an element carrying both fill and stroke builds hollow. So when hand-authoring:
  - use fill-only shapes, never `stroke`;
  - wind every outer contour clockwise in screen coordinates;
  - knock out counters with `fill-rule="evenodd"` subpaths in the same path;
  - never use a white shape to erase.
- **Reference generator:** `gen.py`, handed over with this guide; commit it next to `build.py`. Its helpers implement this spec: `rect`, `rrect`, `frame`, `ring`, `arc`, `arrow_arc`, `pline` (contrast polyline with traps and cuts), `tnotch`/`hnotch`/`stem_traps`, `off_slash` and `badge_x`. Add new concepts as functions there, then emit them.
- **Build and look:**
  ```
  python tool/icons/build.py --svg-dir tool/icons/svg --only a,b,c --sheet /tmp/x/sheet.html --font /tmp/x/sheet.ttf
  render.sh /tmp/x/sheet.html /tmp/x/sheet.png 1600 900
  ```
  Then look at the 14 and 16 px rows enlarged with nearest-neighbour scaling, on both backgrounds.
- **Done means:**
  - the ink is inside the live area;
  - no gap is under 2u (except the off-slash and the calendar texture);
  - no counter is under 2.5u;
  - the glyph is told apart from its §9 siblings at 14 px;
  - it is not mistakable for the Lucide, Material or Phosphor glyph of the same concept.

## 11. Exemplars (from the built set)

`add`: a V stem with an H bar whose arms pinch to 0.9u at the stem.
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="M10.625 3.5H13.375V11.55L15.625 11.125H20.5V12.875H15.625L13.375 12.45V20.5H10.625V12.45L8.375 12.875H3.5V11.125H8.375L10.625 11.55Z"/></svg>
```

`chevronRight`: 45° strokes (2.46u) cut horizontally, a mitred apex, and an inner trap.
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="M6.513 4.25H9.987L17.737 12L9.987 19.75H6.513L13.414 12.849L15.236 12L13.414 11.151Z"/></svg>
```

`bolt`: solid because its counter is under 2.5u, with chisel-cut points 1u wide and traps at both waist corners.
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="M13.7 10.5H19.5L11 22H10L11.291 14.682L12.266 12.857L10.3 13.5H4.5L13 2H14L12.709 9.318L11.734 11.143Z"/></svg>
```

A hand-authored calendar frame shows the rules in §10: an evenodd frame wound clockwise plus rects for the stems and the header. It builds correctly, with an area of 177.6 and 3 contours. Add the traps by turning the stems into polygons.
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
<path fill-rule="evenodd" d="M4 4.5H20A1.5 1.5 0 0 1 21.5 6V20.25A1.5 1.5 0 0 1 20 21.75H4A1.5 1.5 0 0 1 2.5 20.25V6A1.5 1.5 0 0 1 4 4.5ZM5.25 6.25V20H18.75V6.25Z"/>
<rect x="7.75" y="2" width="2.75" height="4"/><rect x="13.5" y="2" width="2.75" height="4"/>
<rect x="4.75" y="8.5" width="14.5" height="1.75"/>
</svg>
```
