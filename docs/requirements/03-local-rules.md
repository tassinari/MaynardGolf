# 03 — Local Rules (modal)

**Artboard:** Local rules modal
**Entry:** Settings › Local rules row, **or** automatically at tee off when "Show at tee off" is on.

## 1. Overview
A full-height `LightSheet` on a Chalk 50 background (radius 36 top), with the presenting screen dimmed behind it in the iOS card style. It has a fixed header and a scrolling list of numbered rule cards.

## 2. Header
| ID | Requirement |
|----|-------------|
| LR-HDR-01 | Centered grabber, 40×5, Chalk 300. Swipe down dismisses (`.presentationDragIndicator(.visible)`). |
| LR-HDR-02 | Title "Local rules" (Title 28, Sofia 700). |
| LR-HDR-03 | Subtitle "{Course name} · updated {Mon YYYY}" (Caption 13, Moss 600). |
| LR-HDR-04 | Trailing 44 pt `CircleIconButton` with a chevron-down icon, accessibility label "Close". Dismisses the sheet. |
| LR-HDR-05 | A hairline separates the header from the scrolling list. The header doesn't scroll. |
| LR-HDR-06 | The sheet's accessibility label is "{Course name} local rules". |

## 3. Rule cards
| ID | Requirement |
|----|-------------|
| LR-RC-01 | A vertical list (gap 10) of `RuleCard`s: white, radius 18, 1 pt border, 14/16 padding. |
| LR-RC-02 | Each card has, on the left, a `NumberChip` (34 pt, radius 10) with the rule number (1-based) on the rule's color, and on the right the title (Inter 600 16), a `TagChip` with a short penalty/relief summary and the body text (Inter 14, line height 1.45, Rough 700). |
| LR-RC-03 | Rule colors encode the rule type: OB = Chalk with a Moss ring, Penalty = Flag 600, Preferred lies = Rough 600, GUR = Lake 600, Cart paths = Bunker 300, Pace = Moss 400. The foreground follows the readable pairings. |
| LR-RC-04 | The default content for Maynard GC (placeholders in brackets must be filled in by the club): |

| # | Title | Tag | Body |
|---|-------|-----|------|
| 1 | Out of bounds | Stroke + distance | Defined by white stakes and the inside edge of the road along the left of [hole]. |
| 2 | Penalty areas | 1 stroke | Red and yellow stakes. The [pond / stream] on [holes] is played as a red penalty area. |
| 3 | Preferred lies | When posted | In closely mown areas through the green, lift, clean and place within one club length, no nearer the hole. |
| 4 | Ground under repair | Free relief | Areas marked with white lines, including the [area] right of [hole]. |
| 5 | Cart paths | Free relief | Paved paths and their edging are immovable obstructions. |
| 6 | Pace of play | 4:15 round | Keep up with the group ahead. Let faster groups play through. |

| ID | Requirement |
|----|-------------|
| LR-RC-05 | Footer (centered, Caption 12, Moss 600): "Rules of Golf apply except where noted. Check the scorecard or pro shop for today's postings." |
| LR-RC-06 | Tag chips don't wrap (`lineLimit(1)`). The title wraps under the tag at large Dynamic Type. |

## 4. Data
| ID | Requirement |
|----|-------------|
| LR-DT-01 | `LocalRule` value type: `id`, `title`, `tag`, `body`, `kind` (enum → color). It's decodable from course JSON (`localRules` array plus `localRulesUpdated` date). |
| LR-DT-02 | Rule text must be localizable. Bundled course JSON holds string keys or per-locale values. |
| LR-DT-03 | `LocalRulesViewModel` exposes the course name, formatted updated date, rule count and rules. |
| LR-DT-04 | A course with no rules hides the Settings section row (or shows "No local rules"). The sheet is never shown empty. |
| LR-DT-05 | Auto-presentation at tee off happens once per round, not again on resume. |

## 5. Accessibility identifiers
`localRules.sheet`, `localRules.close`, `localRules.rule.{n}`.

## Open questions
1. Final rule text for Maynard GC. The official scorecard's rules are in [course-maynard-gc.md §5](course-maynard-gc.md#5-local-rules-printed-on-the-card). Should they replace the design's placeholder rules?
2. Should the rules be editable in the app or only bundled?
