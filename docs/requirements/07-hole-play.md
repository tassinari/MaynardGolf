# 07 — Hole Play (Hole view + Players panel + Enter score)

**Artboards:** iPhone — Hole 1 · Applied — Hole 1, dark mode · Players modal · Enter score modal
**Entry:** New round › Tee off (hole 1), Home › In-progress card (current hole), or Round detail › Edit (completed round, edit mode, §5).
**Replaces:** v1 `HoleViewContainer`, `HoleView`, `HoleViewModel`.

This is one screen with two sheet states layered over it.

## 1. Hole view (base layer)

A full-bleed aerial image of the hole fills the screen, with glass controls and overlays on top. The status bar uses light content.

### 1.1 Hole map background
| ID | Requirement |
|----|-------------|
| HP-MAP-00 | Dark mode follows "Applied — Hole 1, dark mode": dimmed aerial, deeper glass tint, Lake 500 hole badge (DS-MT-05). Overlays and text on glass don't change. |
| HP-MAP-01 | The map is the whole-course map seen through the current hole's camera, filling the screen and ignoring safe areas ([16-hole-map.md](16-hole-map.md)), dimmed in Dark. Accessibility: "Aerial view of hole {n}, par {p}"; VoiceOver swipes up and down change hole. The shot-line overlays (HP-MAP-02…05, #108) and the player's location dot (HP-CTL-03, #57) sit over it. |
| HP-MAP-02 | `ShotLine` overlay from the round's tee box through the target(s) to the pin, only when Settings › "Shot line on map" is on. Full spec: [14-shot-lines.md](14-shot-lines.md). |
| HP-MAP-03 | `PinMarker` at the green's center coordinate, projected to screen space (14-shot-lines §3). |
| HP-MAP-04 | A draggable `TargetMarker` (crosshair) at each landing point (one on a par 3, starting at the green center; two on a par 5) with a glass `YardagePanel` under it showing TO TARGET and TO PIN (14-shot-lines §3–4). |
| HP-MAP-05 | Overlay points are GPS coordinates (tee boxes, approach shots, `greenCoordinates`) placed on screen by the hole camera at rest (`ShotProjection` over `HoleCamera`, 16-hole-map §3). The overlay (`ShotLineOverlay`) sits between the map and the course overview's badges, and only its targets take touches. |
| HP-MAP-06 | Pinch and double-tap zoom are **not** in v2. The map moves only with the hole swipe and the course overview. |

### 1.2 Top bar
| ID | Requirement |
|----|-------------|
| HP-TOP-01 | Top-left `GlassPillButton` "‹ Exit" (accessibility "Exit round"). Tapping it goes straight back to Home, with no confirmation (#172): every score is already saved, and the round stays in progress and resumes from Home. |
| HP-TOP-02 | A 52 pt `GlassIconButton` with only the scorecard grid symbol (`tablecells`), accessibility label "Card", below the hole card, first in the right-aligned controls row (#218). Opens the **Scorecard** (push, or a full-screen sheet). |

### 1.3 Hole number card
| ID | Requirement |
|----|-------------|
| HP-HOLE-01 | `HoleInfoCard`, a glass card (radius 30), at the top-right, sharing a top-aligned row with Exit (or Done when editing), with no separate bar above it (#218): a 60 pt Lake 600 circle with the hole number (SF Pro 700 36), then "PAR {n}" (SF Pro 700 26), "{yds} YDS" (SF Pro 600 21, for the round's tee, always yards) and "HCP {n}" (SF Pro 600 17, Lake 100). |
| HP-HOLE-02 | Accessibility: one element, "Hole 1, par 4, 385 yards, handicap 1". |
| HP-HOLE-03 | It animates (crossfade / slide) when the hole changes. |

### 1.4 Map controls
| ID | Requirement |
|----|-------------|
| HP-CTL-01 | Three 52 pt `GlassIconButton`s in a right-aligned row under the hole card (#218): **Card** (HP-TOP-02), **Course map** (map icon, `hole.courseMap`) and **Show my location** (location-arrow icon, filled while on; accessibility value "On" / "Off", `hole.map.location`), side by side with 12 pt gaps, in the order Card, Course map, Show my location. While the course overview is open the row is hidden with the rest of Hole play's controls; the overview has its own Exit and Show my location (HM-OV-04, 05). |
| HP-CTL-02 | *Course map* zooms out to the whole-course overview, turned and cropped to fill the portrait screen, with a badge in each hole's fairway, Exit and Show my location only; tapping a badge flies to that hole, Exit back to the hole it came from (16-hole-map §5, #227). |
| HP-CTL-03 | *Show my location* asks for When-In-Use location permission on its first tap (X-17), then shows the player's position as a `LocationDot` on the map (DS-OV-12, `hole.myLocation`; like the pin it shows whatever the shot-line setting and fades during moves) and measures the yardage panel's TO TARGET from that position (14-shot-lines SL-YD-04). Tapping it again turns it off. While another screen covers Hole play (the Card) the updates pause and it stays on; they resume on return. If permission is denied, or denied when asked, an alert "Location is off" explains and offers **Settings** (the app's page in the Settings app) or **Not now** (`hole.locationAlert.settings`, `hole.locationAlert.cancel`). With only **Approximate** location (Precise Location off), it stays on but an alert "Precise Location is off" says distances stay from the tee, with the same buttons; turning Precise Location off while on shows it too. Access revoked while it's on turns it off. Only fixes accurate to **30 m** or better are used (`LocationFix`); a vaguer fix, no fix, Approximate location, or a position outside the course map is ignored: TO TARGET is then from the tee and no dot shows. Stopping the updates forgets the last fix, so turning it on again never measures from an old position. `HolePlayViewModel` (`toggleLocation()`, `pauseLocation()` / `resumeLocation()`, `playerPosition`, `locationAlert`) decides all of this over the injected `LocationProviding`, which is `Observable` so the prompt's answer reaches it (`locationState`); unit-tested with a fake. |

### 1.5 Leaderboard (bottom card)
Artboards: "iPhone — Hole 1" (3–4 players), "Hole 1 — two players", "Hole 1 — one player" (#184).

| ID | Requirement |
|----|-------------|
| HP-LB-01 | A glass bottom card (radius 26, 12 pt inset from the sides, 30 pt from the bottom, 10 pt padding). Its layout depends only on the number of players in the round (HP-LB-02…04); players are in round order. |
| HP-LB-02 | **1 player:** one inner card (radius 18, white @ 8 %, 12 pt padding): a 52 pt `PlayerAvatar` (photo or initial) with a 2 pt ring in the player's color, the running total (SF Pro 700 24) over the **full name** (SF Pro 600 17, Chalk), and the hole-score chip (HP-LB-05, 36 pt) at the trailing edge. |
| HP-LB-03 | **2 players:** two inner cards side by side (2-column grid, 8 pt gap), each radius 18, white @ 8 %, 10 pt padding, 10 pt between its parts: a 44 pt `PlayerAvatar` (photo or initial) with a 2 pt ring in the player's color over the **first name** (SF Pro 600 13, Chalk, 4 pt below; no wider than the ringed avatar, a longer name truncates with "…"), then the running total (SF Pro 700 24, filling the middle) and the hole-score chip (36 pt) at the trailing edge. |
| HP-LB-04 | **3–4 players:** a 4-column grid (6 pt gap, padding 10 / 8), one column per player: the first name (SF Pro 600 13, Chalk) over the running total (SF Pro 700 16), centered, with the hole-score chip (30 pt) 5 pt to their right. A name too long for the column truncates with "…"; the total never does. No avatar. With 3 players the columns keep the 4-column width and center. |
| HP-LB-05 | **Hole-score chip:** the player's strokes on the hole shown, in a rounded square (radius 11; bold 16–19 numeral in Lake 100 on Lake 100 @ 16 % with a 1 pt Lake 100 @ 22 % inner border). With no score yet on this hole it's a dashed 1.5 pt Lake 100 @ 35 % outline around a "+" (Lake 100 @ 50 %), accessibility "No score yet". |
| HP-LB-06 | **Running total:** `ToParText` when Settings › "Show to-par scores" is on, otherwise the gross total (HP-DT-04). Under par = Flag 400; even / over = Chalk. A player with **no scores yet** in the round shows **"E"**, whichever the setting. |
| HP-LB-07 | **Tapping** (the only way into score entry; no long-press): **1 player:** anywhere on the card opens **Enter score** for that player, skipping the Players list. **2 players:** each inner card is its own tap target and opens Enter score for its player. **3–4 players:** anywhere opens the **Players** panel (§2). Accessibility: "Enter score for {name}" (1–2 players, one element per player, value = total and hole score) or "Open players" (3–4). |
| HP-LB-08 | **Transition (#209):** there's no system sheet. The bottom card and the panel are one score board with five states: the 3–4 player grid, the 2-player cards, the 1-player card, the Players page and Enter score. The card grows up from the bottom, at its full width, into the panel (Players or Enter score) with a spring that's quicker than a sheet (about 0.35 s) and a small bounce, and shrinks back the same way when it closes; with 1 or 2 players it grows from the whole card, not the tapped half. With 1–2 players, each avatar travels from its card into Enter score's header and back. With 3–4 players, the Players rows and Enter score header draw their own avatars and names: no shared overlay, separate movement, scaling or font-size animation connects a row to the header. These identities appear with their page as the panel opens or changes pages. The hole view stays behind it, dimmed. With Reduce Motion the pages crossfade with no bounce, slide or travelling avatars. It closes with its Close button, a tap on the dimmed area above it, or a drag down. No dropped frames on the oldest supported device. |
| HP-LB-09 | The panel is the same view as the card (`ScoreBoard`): one glass surface whose radius goes from 26 to 44, with a grabber when open; the drag down is on the grabber, so the Players list still scrolls. Its height fits its page (Players or Enter score) and animates between them (§2–3); the Players rows scroll only when they don't fit. The collapsed card keeps its place in the layout while the board is open, so nothing behind it moves (SL-TG-04). The states are a pure `ScoreBoardState` (HP-DT-04); only 1–2 player avatars are drawn over the pages and moved to their spots (`matchedGeometryEffect`). With 3–4 players the identity stays local to each page, with no matched geometry between row and header. |

### 1.6 Hole navigation
| ID | Requirement |
|----|-------------|
| HP-NAV-01 | Navigation is by **swipe only**: swiping horizontally on the map goes to the next / previous hole. The map pans, rotates and zooms from one hole's camera to the next, following the finger (16-hole-map §4). There are no next / previous buttons; the other ways to change hole are the Course map's badges (HM-OV-02) and the Out of order button, which goes back to a missed hole (§1.7). Past hole 1 and the last hole a swipe doesn't change hole: the map stretches toward the hole across the end and springs back (HM-TR-09). |
| HP-NAV-02 | **Auto-advance:** once every player has a score for the current hole, the panel collapses into the card and the view moves to the next hole that isn't complete (HP-OO-06; in normal play, the next hole) **straight away** (the same camera move as a swipe; no pause first, #171). Controlled by Settings › "Auto-advance holes" (SET-OPT-03). Editing a score on an already-complete hole doesn't advance. If the hole has already changed (a swipe), or the course overview is open, it doesn't move; leaving the screen cancels it. |
| HP-NAV-05 | The round has 9 or 18 holes (`Round.holeCount`). For 18, the hole card shows 10–18 while the map and data come from holes 1–9. |
| HP-NAV-03 | Once every hole has every player's score (whichever hole was scored last, HP-OO-06), show **Round complete** ([17-round-complete.md](17-round-complete.md)) after about 600 ms, so the last score is seen; it leads to **Round detail** or Home. |
| HP-NAV-04 | The current hole is saved so a resume lands on the right hole. |

### 1.7 Out of order (missed scores)
Artboard: "Out of order". Players can swipe ahead before every score is in, or skip a player on a hole. This button
shows that an earlier hole is missing a score and takes them back to it.

| ID | Requirement |
|----|-------------|
| HP-OO-01 | A hole is **missed** when it comes before the hole shown and at least one player has no score on it. The hole shown and the holes after it never count. A pure rule (`MissedHoles`) decides this and is unit tested to 100 %. |
| HP-OO-02 | The **Out of order button** shows while the hole shown has at least one missed hole before it. It's hidden when every earlier hole is complete, so always on hole 1 and in a completed round being edited (HP-ED). It updates as soon as a score is saved or the hole changes. |
| HP-OO-03 | **Look:** a 52 pt `GlassIconButton` (DS-BT-07) at the bottom leading edge, 12 pt from the screen's leading edge and 12 pt above the leaderboard. Its icon is the scorecard glyph (`tablecells`, the Card button's icon, in Chalk at `GlassIconButton`'s icon size). A warning badge (DS-BT-07) sits on its top-trailing edge, offset 10 pt outward: a Caution 400 triangle with a Canopy 950 exclamation mark and a 2 pt Canopy 950 outline, about 30 × 28 pt. |
| HP-OO-04 | **Tap:** the view goes to the **lowest** missed hole. One hole back uses the auto-advance camera move (HM-TR-03, about 0.9 s), in reverse. Further back, the camera flies out to the course overview and in to that hole, 0.35 s each way (HM-TR-03, HM-OV-01, 02). The hole card crossfades (HP-HOLE-03), and the new hole is saved (HP-NAV-04). With Reduce Motion, or before the overview image has loaded, the map crossfades (HM-TR-06). Drags wait until the move ends, and the overview's badges don't appear on the way. The panel doesn't open: the player taps the leaderboard to enter the missing scores. |
| HP-OO-05 | The button isn't shown while the course overview is open (browsed or flown through, HM-OV-04); it fades back in as the camera starts back to a hole. It fades out when a hole transition starts and back in at rest, like the shot lines (HM-TR-04). While the score panel is open, the dimmed area covers it and it takes no taps. |
| HP-OO-06 | **Auto-advance after a missed hole:** when a save completes a hole, auto-advance (HP-NAV-02) moves to the next hole after it that isn't complete. If every later hole is complete, it moves to the lowest hole that isn't (so finishing the last hole before an earlier one goes back to it). In normal play the next hole isn't complete yet, so the behavior is unchanged. The camera move follows HP-OO-04: the auto-advance move to a neighbour, the overview flight to a hole further away. It runs only if the hole that was scored is still the one shown and the overview is closed (`shouldAdvance(from:)`), so a swipe in between wins. If every hole is complete, Round complete shows (HP-NAV-03), which already requires every score in the round. A pure rule (`MissedHoles.advanceTarget`), unit tested to 100 %. |
| HP-OO-07 | **Accessibility:** one button. Label "Missed score on hole {n}", hint "Goes back to hole {n}.", identifier `hole.outOfOrder`. |
| HP-OO-08 | **Clear of the course:** the button's corner is a control region for the hole cameras: no tee box, approach shot or pin sits under it at rest (HM-CAM-02, checked by `CourseDataTests`; holes 5 and 7 were reframed for it). While it shows, a dragged target stays above it: the bottom of the playable area (SL-TG-04) rises to the top of its badge across the width of the screen. Overlays still don't move to avoid it (SL-DR-07). |

## 2. Players panel (3–4 players)

The leaderboard card grown into a panel (HP-LB-08, 09) over the dimmed hole view. The top bar and hole card stay visible behind it. With 1 or 2 players there's no Players page: the card opens straight into Enter score (HP-LB-07).

| ID | Requirement |
|----|-------------|
| HP-PS-01 | The panel's first page, sized to its rows (about half the screen for 4 players). |
| HP-PS-02 | Header: title "Hole {n}" (SF Pro 600 22, Chalk) and subtitle "PAR {p}" (SF Pro 600 15 caps, Lake 100); the hole card already shows the yards. Trailing 44 pt glass `CircleIconButton` (chevron-down, "Close") collapses the panel back into the card. |
| HP-PS-03 | One 72 pt row per player, with hairline (Chalk @ 18 %) separators between them: 48 pt avatar, first name (SF Pro 600 17), running total `ToParText` (SF Pro 700 18; under = Flag 400, else Lake 100) and a trailing score chip: the bottom card's `HoleScoreChip` at 44 pt (radius 13, DS-GF-09), on the panel's glass, never a filled `PrimaryButton`. With no score on this hole it's the dashed "+". The whole row is one button (#216): a tap anywhere on it opens that player's Enter score, not only on the chip; VoiceOver reads "Enter score for {name}". The first name stays on one line with "…". |
| HP-PS-04 | When a player already has a score for this hole, the button shows it (the Lake 100 numeral, e.g. "3") and stays tappable to edit; VoiceOver reads "Edit score for {name}, {n}". |
| HP-PS-05 | A row's tap **pushes** that player's Enter score page inside the same panel, not a second modal: the Players rows slide out to the leading edge, Enter score slides in from the trailing edge while the panel resizes to fit, and each page draws its own player name and avatar. Neither identity travels, scales or morphs between the row and header (HP-LB-08). "Back to players" reverses the page transition without a separate name or avatar animation. |
| HP-PS-06 | After a score is saved and someone on this hole still has no score, the panel pops back to the Players page. |
## 3. Enter score

A page of the panel: pushed from Players with 3–4 players, or the panel's only page with 1–2 players (HP-LB-07).

| ID | Requirement |
|----|-------------|
| HP-ES-01 | Accessibility label "Enter score for {name}". |
| HP-ES-02 | With 3–4 players the header draws its own avatar and name, without matched geometry or a separate identity animation from the Players row. Header: 48 pt avatar, player first name (SF Pro 600 22, one line with "…"), "HOLE {n} · PAR {p} · {yds} YDS" subtitle and a trailing glass circle button that leaves without saving: with 3–4 players "Back to players" (chevron-left, pops to the Players page); with 1–2 players "Close" (chevron-down, `score.close`, collapses the panel into the card). |
| HP-ES-03 | **Stepper**: a 68 pt round "−" button (accessibility "Decrease score"), a large score numeral in the center (SF Pro 700, about 96 pt) with a `ScoreNameBadge` under it, and a 68 pt round "+" button ("Increase score"). The range is **1–12** (12 is the fixed upper bound, not tied to the net double-bogey posting cap). The buttons disable at the bounds. |
| HP-ES-04 | Initial value = the existing score for this hole if there is one, otherwise **par**. |
| HP-ES-05 | Score name: 1 = **ACE** (whatever the par), otherwise from score − par: −3 ALBATROSS, −2 EAGLE, −1 BIRDIE, 0 PAR, +1 BOGEY, +2 DOUBLE, +3 TRIPLE, more than +3 "OVER", less than −3 "UNDER". Badge color: under par Flag 600 / white, par Chalk / Canopy, over Lake 600 / white. |
| HP-ES-06 | **Quick picks**: a row of 4 64 pt tiles for par − 1 … par + 2 (for par 4: 3 Birdie, 4 Par, 5 Bogey, 6 Double). Each tile shows the number and the score name. The selected tile is solid Chalk with Canopy text. The others are glass. Tapping one sets the value. |
| HP-ES-07 | `PrimaryButton` "Save score" (56 pt, full-width) saves the score for this player and hole, updates the leaderboard and fires the `.success` haptic. Then: **1 player:** the panel collapses (and auto-advance runs, HP-NAV-02). **2 players:** every successful save collapses the panel back to the two-player leaderboard, including when the other player has no score (#225). Tap the other player’s card to open their entry; never hand off automatically. Auto-advance waits until both players have a score (HP-NAV-02). **3–4 players:** back to Players if someone is still unscored (HP-PS-06), otherwise it collapses. |
| HP-ES-08 | The stepper and quick picks fire a `.selection` haptic. There's no in-app Haptics setting; the system setting applies. |
| HP-ES-09 | VoiceOver: the score numeral is an adjustable element (swipe up / down changes the value) labeled "Score, 4, Par". |
| HP-ES-10 | *Inferred, not built yet:* a "Clear score" option for editing an existing score (long-press or a secondary button). It needs a repository call to clear a stroke, which doesn't exist yet. |

## 4. Data and ViewModel
| ID | Requirement |
|----|-------------|
| HP-DT-01 | `HolePlayViewModel` takes the round's id and is injected with `RoundRepository` (`round(id:)`), `CourseProvider`, `SettingsStore` and `HapticsProviding` (location joins with the map, #57). It exposes `currentHole`, `hole` and `yards`, `cards` (the leaderboard, in round order) with `total(_:)`, `board: .collapsed / .players / .entering(cardID, ScoreEntryModel)` (the score board's page, with the value being entered; one enum so a value can't outlive its page), `boardState` (the `ScoreBoardState` the view draws, HP-LB-08), `leaderboardLayout` (`.one` / `.two` / `.grid` by player count), what a tap on a player's card opens (`tap(card:)`), `entry` and `scoringCard` (read from `board`), and `missedHole` (HP-OO-01). `save()` returns what follows: `.nextPlayer`, `.stay`, `.advance(from:to:)`, `.finished` or `.failed`; the view runs it in a task that's cancelled if the screen goes away (Round complete after 600 ms, HP-NAV-03), and moves the camera only if `shouldAdvance(from:)` says the scored hole is still the one shown (HP-OO-06). A failed save shows "The score couldn't be saved. Try again."; a round that can't be read shows "The round couldn't be loaded." with Try again; a round deleted elsewhere closes the screen. A player removed elsewhere while the board is open never leaves an empty panel: Players closes when fewer than 3 players remain, and that player's Enter score goes back to Players (3–4 players) or collapses (1–2). |
| HP-DT-02 | Saving a score writes `RoundEntry.setStrokes(_:forHole:)` and recalculates totals. The Home in-progress card and the Scorecard update through observation (no NotificationCenter). |
| HP-DT-03 | Score entry logic (bounds, initial value, name, color, quick-pick range) lives in a pure `ScoreEntryModel` with 100 % unit coverage. |
| HP-DT-04 | Leaderboard totals count holes **with** a score only. To-par is calculated against the par of those holes. No scores at all → "E" (HP-LB-06). The layout, tap targets and what follows a save by player count are pure rules (`LeaderboardLayout`), and the score board's five states, where each avatar sits, whether the layout uses a shared avatar (1–2 players only), and which way pages slide are a pure `ScoreBoardState`; both 100 % unit-tested. |

## 5. Edit mode (completed round)
Reached from Round detail › Edit (10-round-detail §6). Same screen and sheets; only the differences are listed.

| ID | Requirement |
|----|-------------|
| HP-ED-01 | Opens at hole 1 of the completed round. Every hole already has scores, so the leaderboard shows final totals and the Enter score sheet starts from each player's saved score (HP-ES-04). |
| HP-ED-02 | The top-left button reads "Done" (accessibility "Done editing") instead of "‹ Exit". It returns to Round detail with **no** "Leave round?" confirmation, since every change is already saved. |
| HP-ED-03 | Auto-advance doesn't apply (every hole is already complete; HP-NAV-02 only fires when a hole becomes complete). Navigation is swipe only. |
| HP-ED-04 | Round complete (HP-NAV-03) isn't shown again, and the round stays `complete` with its original `finishedAt`. Moving between holes doesn't change the round's saved current hole. |
| HP-ED-05 | A score can be changed but not cleared, so the round stays complete. (HP-ES-10's "Clear score" isn't built; when it is, it's hidden in edit mode.) |
| HP-ED-06 | The Card button and Scorecard work as usual (read-only). |
| HP-ED-07 | `HolePlayViewModel` takes a `mode: .play / .edit`; Round detail › Edit pushes `Destination.editRound` (`-uiTestRoute editRound`), which builds it with `.edit`. Unit-tested: hole 1, no saved current hole, no advance or finish, `finishedAt` kept. |

## 6. Accessibility identifiers
`hole.exit`, `hole.done`, `hole.card`, `hole.infoCard`, `hole.map` (the paging photos), `hole.error.retry`, `hole.courseMap`, `hole.map.location`, `hole.myLocation`, `hole.locationAlert.settings`, `hole.locationAlert.cancel`, `hole.outOfOrder` (HP-OO-07), `hole.leaderboard`, `hole.leaderboard.{entryId}` (each player's card or column; the tap target with 1–2 players; its accessibility value is the total and the hole score, e.g. "Even par, No score yet"), `hole.openPlayers` (the 3–4 player grid's button), `hole.panel` (the expanded board), `players.sheet` and `score.sheet` (only while that page shows; the board keeps its pages in the view), `players.close`, `players.enterScore.{entryId}`, `score.back` (3–4 players), `score.close` (1–2 players), `score.decrease`, `score.increase`, `score.value`, `score.name`, `score.quick.{n}`, `score.save`.
