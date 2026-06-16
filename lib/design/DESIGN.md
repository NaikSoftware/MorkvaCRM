# MorkvaCRM Design System — "Warm Carrot"

The single source of truth for how MorkvaCRM looks and feels. Every screen reads
from these tokens and components — never hardcode a hex value, font, radius, or
spacing in a widget.

```dart
import 'package:morkva_crm/design/design.dart';
```

## 1. Visual theme & atmosphere
A warm-paper workspace: a carrot-orange action color floating on soft cream
neutrals, characterful grotesque headings, and quiet data surfaces. Energy lives
in the accent and micro-interactions; tables and boards stay calm so dense
content reads without fatigue. Modern, friendly, dependable — never stock
Material.

## 2. Color palette & roles
Read colors from `Theme.of(context).colorScheme` and the
`MorkvaSemanticColors` theme extension. Raw values live in `tokens/colors.dart`.

| Role | Light | Meaning |
|------|-------|---------|
| primary (carrot) | `#E8821E` | primary actions, active nav, focus |
| secondary (leaf) | `#4C7A34` | secondary accents (carrot-top green) |
| surface (canvas) | `#FBF7F2` | main work area background |
| surfaceContainer | `#F4EDE3` | nav rail / sidebar (steps down from canvas) |
| surfaceContainerLowest | `#FFFFFF` | cards, sheets (steps up, + soft shadow) |
| onSurface | `#2B2018` | primary text (warm near-black ink) |
| onSurfaceVariant | `#6B5E52` | secondary text |
| outline / outlineVariant | `#B6A593` / `#E0D5C7` | dividers, borders |
| success / warning / error / info | `#2E8B57` / `#D4A017` / `#C0392B` / `#3A7CA5` | semantic (via `MorkvaSemanticColors`) |

Dark mode mirrors with warm espresso surfaces and a brighter carrot
(`#F59B3C`); depth comes from surface-color steps, not shadows.

## 3. Typography
`tokens/typography.dart` builds the `TextTheme`.
- **Bricolage Grotesque** — display, headline, titleLarge (the brand voice).
- **Hanken Grotesk** — body, labels, data.
- Display sizes carry negative tracking (−1.0 at 48px → −0.2 at 18px).
- **Numbers in data cells:** wrap with `MorkvaTypography.tabular(style)` for
  tabular figures so digits align.

## 4. Components (states)
Built in `components/`. Every interactive component uses `PressableScale`
(press → `scale(0.96)`, reduced-motion aware) and reads theme/tokens.
- **PrimaryButton** (exemplar): solid carrot, `onPrimary` label, 44px tall,
  radius `md` (12); states: default, pressed (scale), disabled (38% opacity),
  loading (spinner). Supports leading icon and `expand`.
- Secondary / text / icon buttons, inputs, cards, app bar, empty-state, and
  loading follow the same rules (see barrel `design.dart`).

## 5. Layout & spacing
`tokens/spacing.dart`: 4 / 8 / 12 / 16 / 24 / 32 / 48 (`xxs…xxl`). Default
content padding `md` (16); section gaps `lg` (24). No magic numbers.

## 6. Depth & elevation
`tokens/elevation.dart`: soft warm-tinted shadows `level1…level3` for cards,
hovered cards, and menus. Adjacent surfaces stay distinguishable by a ≥4%
lightness step (sidebar `surfaceContainer` vs canvas `surface`) **or** a card
shadow — never a white card on near-white with an invisible shadow.

## 7. Do / Don't
- **Do** read from `ColorScheme`, `TextTheme`, and tokens.
- **Do** give every pressable the `PressableScale` feel and a 44px hit area.
- **Do** use tabular figures for numbers; sentence case for headings.
- **Don't** hardcode colors, fonts, radii, or spacing in widgets.
- **Don't** use stock Material drop shadows, or bounce/elastic easing.
- **Don't** put a warning in carrot — warning is the distinct amber `#D4A017`.

## 8. Responsive behavior
One breakpoint at **840dp**: `< 840` = compact (bottom navigation),
`>= 840` = expanded (navigation rail). Touch targets ≥ 44px. The `AppShell`
owns this; components are width-agnostic.

## 9. Radius & motion quick reference
- Radius: `sm` 8 (chips), `md` 12 (buttons/inputs), `lg` 16 (cards),
  `full` 28 (pills/nav indicator).
- Motion: `fast` 120ms (press), `base` 200ms (state), `slow` 320ms (reveals);
  curve `MotionCurves.emphasized` = `cubic-bezier(0.16,1,0.3,1)`. Always honor
  `MediaQuery.disableAnimationsOf(context)`.
