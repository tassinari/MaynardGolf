# 03 — Local Rules (modal)

**Artboard:** Local rules modal
**Entry:** Settings › Local rules row (the only entry point; there's no automatic presentation at tee off).
**Exit:** Close button or swipe down → back to Settings.

## 1. Overview
A full-height `LightSheet` on a Chalk 50 background (radius 36 top), with the presenting screen dimmed behind it in the iOS card style. It has a fixed header and a scrolling list of numbered rules. The rules are the ones printed on the official Maynard GC scorecard ([course-maynard-gc.md](course-maynard-gc.md) §5): plain text only, with no titles, penalty tags or rule categories.

## 2. Header
| ID | Requirement |
|----|-------------|
| LR-HDR-01 | Centered grabber, 40×5, Chalk 300. Swipe down dismisses (`.presentationDragIndicator(.visible)`). |
| LR-HDR-02 | Title "Local rules" (Title 28, Sofia 700). |
| LR-HDR-03 | Subtitle "{Course name}": "Maynard Golf Club" (Caption 13, Moss 600). There's no "updated" date. |
| LR-HDR-04 | Trailing 44 pt `CircleIconButton` (Chalk 200) with a chevron-down icon, accessibility label "Close". Dismisses the sheet. |
| LR-HDR-05 | A hairline (Card Border) separates the header from the scrolling list. The header doesn't scroll. |
| LR-HDR-06 | The sheet's accessibility label is "{Course name} local rules". |

## 3. Rule list
| ID | Requirement |
|----|-------------|
| LR-RC-01 | A vertical list (gap 10, padding 14/16, 40 bottom) of `RuleCard`s: white (`surfaceCard`), radius 18, 1 pt Card Border inset, padding 14/16, gap 14. |
| LR-RC-02 | Each card has, on the left, a `NumberChip` (30 pt, radius 9, Tee Green 50 background, Rough 600 number in Sofia 700 17) with the rule number (1-based). On the right, the rule text (Inter 400 15, line height 1.45, `textPrimary`), top-aligned with the chip (4 pt top padding) and wrapping freely. |
| LR-RC-03 | All chips use the same color. Rules have no type or color coding. |
| LR-RC-04 | Each card is one accessibility element read as "Rule {n}. {text}". |
| LR-RC-05 | Content for Maynard GC (12 rules, as in the design, from the scorecard): |

| # | Text |
|---|------|
| 1 | USGA Rules govern play unless amended by local rules. |
| 2 | OUT OF BOUNDS: Parking lot, off club property defined by white stakes. |
| 3 | Ball coming to rest in a bark mulch area may be lifted and dropped one club length, no nearer the hole, with no penalty. |
| 4 | All service roads, cart paths, fairway drainage ditches, and protective fences, free lift to nearest point of relief, no nearer the hole. |
| 5 | Ball coming to rest in the confines of a rock or rocks through the green may be moved one club length without penalty. |
| 6 | Players not holding their places on golf course must allow other groups to play through. |
| 7 | Players on 1st tee must alternate with players coming off 9th green. |
| 8 | Do not climb face of bunkers. Rake bunkers and return rake to inside the bunker. |
| 9 | Keep all carts off aprons and greens. |
| 10 | Repair ball marks on green. Replace divots. |
| 11 | Please speed up play. |
| 12 | Maynard Golf Course is a soft spike facility. |

| ID | Requirement |
|----|-------------|
| LR-RC-06 | No footer below the list. |
| LR-RC-07 | Dark mode uses the semantic tokens (`background`, `surfaceCard`, `cardBorder`, `textPrimary`, `textSecondary`). *Inferred:* the chip uses a Raised background with a Green 200 number. |

## 4. Data
| ID | Requirement |
|----|-------------|
| LR-DT-01 | `LocalRule` value type: `id` and `text` only (no title, tag or kind). It's decodable from course JSON as a `localRules` string array, in display order. The number is the position, not stored. |
| LR-DT-02 | Rule text must be localizable. Bundled course JSON holds String Catalog keys (e.g. `localRule.maynard.1`) with English values in `Localizable.xcstrings`. |
| LR-DT-03 | `LocalRulesViewModel` exposes the course name, rule count and numbered rules. |
| LR-DT-04 | A course with no rules hides the Settings section row. The sheet is never shown empty. |

## 5. Accessibility identifiers
`localRules.sheet`, `localRules.close`, `localRules.rule.{n}`.
