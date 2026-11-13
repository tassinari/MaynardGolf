# 07 — Hole Play (Hole view + Players sheet + Enter score sheet)

**Artboards:** iPhone — Hole 1 · Players modal · Enter score modal
**Entry:** New round › Tee off (hole 1), or Home › Resume round (current hole).
**Replaces:** v1 `HoleViewContainer`, `HoleView`, `HoleViewModel`.

This is one screen with two sheet states layered over it.

## 1. Hole view (base layer)

A full-bleed aerial image of the hole fills the screen, with glass controls and overlays on top. The status bar uses light content.

### 1.1 Hole map background
| ID | Requirement |
|----|-------------|
| HP-MAP-01 | A full-screen aerial image of the current hole (`holeIconName` asset or a hi-res aerial), aspect-fill, ignoring safe areas. Accessibility: "Aerial view of hole {n}, par {p}". |
| HP-MAP-02 | `ShotLine` overlay from the tee to the pin, only when Settings › "Shot line on map" is on. |
| HP-MAP-03 | `PinMarker` at the green's center coordinate, projected to screen space. |
| HP-MAP-04 | `LandingMarker` (Lake 200 dot) at the line's midpoint / layup point (*inferred*: the fairway target). |
| HP-MAP-05 | The overlay projection uses `greenCoordinates` and the tee coordinate from course data through an injectable `MapProjection`. |
| HP-MAP-06 | *Inferred:* pinch / double-tap zoom is **not** required in v2 (the map is a static image). |

### 1.2 Top bar
| ID | Requirement |
|----|-------------|
| HP-TOP-01 | Top-left `GlassPillButton` "‹ Exit" (accessibility "Exit round"). Tapping it asks "Leave round? Your scores are saved and you can resume from Home." (Leave / Stay). Leave pops to Home. The round stays in progress. |
| HP-TOP-02 | Top-right `GlassPillButton` "Card" with a scorecard grid icon. Opens the **Scorecard** (push, or a full-screen sheet). |

### 1.3 Hole number card
| ID | Requirement |
|----|-------------|
| HP-HOLE-01 | `HoleInfoCard`, a glass card (radius 30), right-aligned under the top bar: a 60 pt Lake 600 circle with the hole number (Sofia 700 36), then "PAR {n}" (Sofia 700 26), "{yds} YDS" (Sofia 600 21, for the round's tee, unit from Settings) and "HCP {n}" (Sofia 600 17, Lake 100). |
| HP-HOLE-02 | Accessibility: one element, "Hole 1, par 4, 385 yards, handicap 1". |
| HP-HOLE-03 | It animates (crossfade / slide) when the hole changes. |

### 1.4 Map controls
| ID | Requirement |
|----|-------------|
| HP-CTL-01 | Two 52 pt `GlassIconButton`s under the hole card: **Course map** (folded-map icon) and **Show my location** (location-arrow icon). |
| HP-CTL-02 | *Course map* opens a hole picker / course overview so you can jump to any hole (*inferred*). |
| HP-CTL-03 | *Show my location* asks for When-In-Use location permission on first use, then shows the user's position and the distance to the green (front / center / back) from `Location.swift`. If denied, show an alert with a Settings link. |

### 1.5 Leaderboard (bottom card)
| ID | Requirement |
|----|-------------|
| HP-LB-01 | A glass bottom card (radius 26, 12 pt inset from the edges, 30 pt from the bottom) with a 4-column grid, one column per player in round order. |
| HP-LB-02 | Each column: 44 pt `PlayerAvatar`, first name (Inter 600 14, Chalk) and running total (Sofia 700 22). |
| HP-LB-03 | The running total shows `ToParText` when Settings › "Show to-par scores" is on, otherwise the gross total. Under par = Flag 400. Even / over = Chalk. |
| HP-LB-04 | Tapping anywhere on the leaderboard opens the **Players sheet** (accessibility "Open players"). |
| HP-LB-05 | 1–3 players: columns center and keep a fixed width. |
| HP-LB-06 | *Inferred:* a player who already has a score for the current hole shows a small check / score badge on the avatar. |

### 1.6 Hole navigation (inferred — not shown in the visuals)
| ID | Requirement |
|----|-------------|
| HP-NAV-01 | Swiping horizontally on the map goes to the next / previous hole (a paged `TabView`). |
| HP-NAV-02 | With auto-advance on, after the last score for a hole is saved, go to the next hole after about 600 ms. |
| HP-NAV-03 | After the final hole is scored for every player, show **Round complete** (the v1 `RoundCompleteView`, restyled), then open **Round detail**. |
| HP-NAV-04 | The current hole is saved so a resume lands on the right hole. |

## 2. Players sheet

A `GlassSheet` over the dimmed hole view. The top bar and hole card stay visible behind it.

| ID | Requirement |
|----|-------------|
| HP-PS-01 | `.sheet` with a medium-ish detent sized to the content, radius 44, 8 pt inset, grabber. |
| HP-PS-02 | Header: title "Players" (Inter 600 22, Chalk) and subtitle "HOLE {n} · PAR {p} · {yds} YDS" (Sofia 600 15 caps, Lake 100). Trailing 44 pt glass `CircleIconButton` (chevron-down, "Close") dismisses. |
| HP-PS-03 | One 72 pt row per player, with hairline (Chalk @ 18 %) separators between them: 48 pt avatar, first name (Inter 600 17), running total `ToParText` (Sofia 700 18; under = Flag 400, else Lake 100) and a trailing `PrimaryButton` "Enter score" (44 pt). |
| HP-PS-04 | When a player already has a score for this hole, the button shows the score (e.g. "4 · Par") and stays tappable to edit. *Inferred.* |
| HP-PS-05 | "Enter score" opens the **Enter score sheet** for that player (it replaces the sheet content; Back returns here). |
| HP-PS-06 | *Inferred:* after a score is saved, focus moves to the next unscored player. |

## 3. Enter score sheet

| ID | Requirement |
|----|-------------|
| HP-ES-01 | `GlassSheet` (radius 44), accessibility label "Enter score for {name}". |
| HP-ES-02 | Header: 48 pt avatar, player name (Inter 600 22), "HOLE {n} · PAR {p} · {yds} YDS" subtitle and a trailing glass circle button (accessibility "Back to players") that returns to the Players sheet without saving. |
| HP-ES-03 | **Stepper**: a 68 pt round "−" button (accessibility "Decrease score"), a large score numeral in the center (Sofia 700, about 96 pt) with a `ScoreNameBadge` under it, and a 68 pt round "+" button ("Increase score"). The range is **1–12**. The buttons disable at the bounds. |
| HP-ES-04 | Initial value = the existing score for this hole if there is one, otherwise **par**. |
| HP-ES-05 | Score name: 1 = **ACE** (whatever the par), otherwise from score − par: −3 ALBATROSS, −2 EAGLE, −1 BIRDIE, 0 PAR, +1 BOGEY, +2 DOUBLE, +3 TRIPLE, more than +3 "OVER", less than −3 "UNDER". Badge color: under par Flag 600 / white, par Chalk / Canopy, over Lake 600 / white. |
| HP-ES-06 | **Quick picks**: a row of 4 64 pt tiles for par − 1 … par + 2 (for par 4: 3 Birdie, 4 Par, 5 Bogey, 6 Double). Each tile shows the number and the score name. The selected tile is solid Chalk with Canopy text. The others are glass. Tapping one sets the value. |
| HP-ES-07 | `PrimaryButton` "Save score" (56 pt, full-width) saves the score for this player and hole, closes back to the hole view (or to Players if others are still unscored, *inferred*), updates the leaderboard and fires the `.success` haptic if Haptics is on. |
| HP-ES-08 | The stepper and quick picks fire a `.selection` haptic if Haptics is on. |
| HP-ES-09 | VoiceOver: the score numeral is an adjustable element (swipe up / down changes the value) labeled "Score, 4, Par". |
| HP-ES-10 | *Inferred:* a "Clear score" option for editing an existing score (long-press or a secondary button). |

## 4. Data and ViewModel
| ID | Requirement |
|----|-------------|
| HP-DT-01 | `HolePlayViewModel` is injected with `RoundRepository`, `CourseProvider`, `SettingsStore`, `HapticsService`, `LocationService` and a `Clock`. It exposes `currentHole`, `holeInfo`, `leaderboard: [LeaderboardEntry]`, `sheet: .none / .players / .enterScore(PlayerID)`, `pendingScore`. |
| HP-DT-02 | Saving a score writes `PersonRound.score[hole]` and recalculates totals. The Home in-progress card and the Scorecard update through observation (no NotificationCenter). |
| HP-DT-03 | Score entry logic (bounds, initial value, name, color, quick-pick range) lives in a pure `ScoreEntryModel` with 100 % unit coverage. |
| HP-DT-04 | Leaderboard totals count holes **with** a score only. To-par is calculated against the par of those holes. |

## 5. Accessibility identifiers
`hole.exit`, `hole.card`, `hole.info`, `hole.map.course`, `hole.map.location`, `hole.leaderboard`, `hole.leaderboard.{playerId}`, `players.sheet`, `players.close`, `players.enterScore.{playerId}`, `score.sheet`, `score.back`, `score.decrease`, `score.increase`, `score.value`, `score.name`, `score.quick.{n}`, `score.save`.

## Open questions
1. Hole navigation isn't shown. Is swipe paging right, or should there be explicit next / previous controls?
2. Is the leaderboard tap the only way into score entry, or should a long-press on an avatar open that player's Enter score directly?
3. Maynard GC has 9 holes: does an 18-hole round loop holes 1–9 with the same aerials?
4. Should the stepper's upper bound be 12, or follow the net double-bogey maximum for handicap posting?
