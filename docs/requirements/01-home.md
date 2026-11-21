# 01 — Home

**Artboards:** one player small cells (marquee player) · Home (round in progress) · Home — no round in progress · Home — one player · Home — two players · Home — fresh install
**Entry:** App launch (root of `NavigationStack`).

## 1. Overview

Home is the app's root. It shows a photo hero, a card to resume any round in progress, the player list and recent rounds. Two things are chosen from the data, independently: whether a round is in progress, and how the Players section is laid out. Marquee player ([story #197](https://github.com/tassinari/MaynardGolf/issues/197), specified; not implemented yet) adds a selected-player layout before the existing count-based layouts.

| Round state | Condition | Shows |
|-------|-----------|-------|
| **In progress** | At least one incomplete round exists | Hero, In-progress card(s), Players, Recent rounds |
| **No round** | Players exist, no incomplete round | Hero, Players, Recent rounds |
| **Fresh install** | No players | Hero, Players empty state, Recent rounds empty state |

| Players layout | Condition (first matching row wins) | Players section |
|-------|-----------|-------|
| **Empty** | 0 players | Empty state (§4.1) |
| **Marquee** | A marquee player is selected | One detailed summary card with chart, followed by up to 3 compact rows for other players (§4.5) |
| **One player** | None selected; 1 player | Header "PLAYER" + one large player summary card **with** a 12-month handicap chart (§4.2) |
| **Two players** | None selected; 2 players | Header "PLAYERS" + two player summary cards **without** the chart, stacked (§4.3) |
| **List** | None selected; 3 or more players | Header "PLAYERS" + the standard list of up to 4 player rows (§4) |

The players layout depends on the marquee selection first, then the player count when None is selected; it never depends on whether a round is in progress. In-progress cards sit above Players in every layout. The first player created is marquee by default (DM-PL-12).

The screen background is the `background` token (Chalk 50 / Canopy 950) and scrolls vertically, with 16 pt side gutters and 18 pt between sections.

> **No "me" concept.** The app belongs to whoever is holding the phone. No player is marked as the user. There's no "You" subtitle, no "You won" and no "This is me" flag anywhere in the app.

## 2. Hero header

| ID | Requirement |
|----|-------------|
| HOME-HDR-01 | A 230 pt full-bleed scrolling photo hero ignores the top safe area. A separate navigation bar is pinned in the top safe area, so Settings and New round remain visible at every scroll position (#212). The course photo (green, white pin flag and autumn trees), aspect-fill, is drawn once in the scrolling hero, as on the original Home screen. Pulling past the top stretches that image upward to cover the overscroll; the pinned bar never draws a separate crop. Accessibility description: "Golf green with a white pin flag and autumn trees". |
| HOME-HDR-02 | A vertical gradient overlay (Canopy 35 % at top → clear at 30–50 % → Canopy 75 % at bottom) keeps the controls and title readable. At the top the navigation bar is clear over the photo; once content scrolls under it, it adds the standard navigation bar’s translucent material, Chalk tint and hairline over the scrolling content. In Dark mode the single hero photo is dimmed (DS-MT-05). |
| HOME-HDR-03 | The pinned navigation bar has a leading 44 pt `GlassIconButton` with a gear icon, accessibility label "Settings". It pushes **Settings** from both expanded and scrolled states. |
| HOME-HDR-04 | The pinned trailing `GlassPillButton` shows "＋ New round" at the top and only the ＋ icon while scrolled. Its label remains "New round", its touch target remains at least 44 pt, and the same button presents **New round** full-screen in both states. Returning to the top restores the full label. |
| HOME-HDR-05 | At the top, "Maynard Golf" is the bottom-left hero title in Title XL (SF Pro 700 44), Chalk, with a shadow. While scrolled, that title is hidden and appears instead as the navigation bar’s centered Body title (SF Pro 400 16), in its original case and fixed black in both appearances, over the standard bar material. The hero retains its height during the transition; returning to the top restores the expanded title. |
| HOME-HDR-06 | The hero is the bundled `HomeHero` photo (`HomeViewModel.heroImageName`). The course data has no per-course hero yet; when it gets one, this bundled photo stays the fallback. |
| HOME-HDR-07 | "New round" always works, even while a round is in progress. **Two (or more) rounds in progress at once are allowed**; there's no warning. |

## 3. In-progress round card (state: In progress)

| ID | Requirement |
|----|-------------|
| HOME-IPR-01 | `surfaceCard` card, radius 24, 20 pt padding, 1 pt border. The whole card is one button, with the ✕ (HOME-IPR-02) a separate button laid over it (accessibility label "Resume round in progress", value "Hole {n} of {9 \| 18}"). |
| HOME-IPR-02 | Top row: `StatusPill` "IN PROGRESS" (left) and a **✕** (right, `DiscardRoundButton`): a 26 pt circle in `underPar` @ 14 % with an `underPar` ✕, in a 44 pt hit area 12 pt from the card's top and right edges, accessibility label "Discard round" (HOME-IPR-08). Below the players, bottom left: "HOLE {n} OF {9 \| 18}" caps label in `textSecondary`. `n` = the first hole where not every player has a score. The total is the round's hole count (chosen at New round). |
| HOME-IPR-03 | A 4-column grid with one column per player in the round, in order: 48 pt `PlayerAvatar`, first name (SF Pro 600 14), `ToParText` (SF Pro 700 20) for holes completed. |
| HOME-IPR-04 | Under-par values use `underPar` (Flag 650 light / Flag 400 dark). Even ("E") and over-par use `textSecondary`. When Settings › "Show to-par scores" is off, show gross totals instead. |
| HOME-IPR-05 | No button on the card: the whole card is the hit target (#211 removed the "Resume round" button). |
| HOME-IPR-06 | Tapping it pushes **Hole play** at the current hole. |
| HOME-IPR-07 | With several incomplete rounds, Home shows **one In-progress card per round** in a vertical list (gap 12), newest first. Each card resumes its own round. They also appear in **All rounds** with an "In progress" pill. |
| HOME-IPR-08 | The ✕ (HOME-IPR-02), a swipe (HOME-IPR-09) and a long press ("Discard round" in the menu) all ask first ("Discard this round?", "The round will be moved to Deleted rounds.", destructive "Discard round"), then delete the round and Home redraws. Cancel keeps the card. A delete that fails keeps the card and shows an alert "The round couldn't be discarded." with OK (X-11); not the banner, whose "Try again" only reloads Home. |
| HOME-IPR-09 | *Not drawn:* **swipe left** on a card uncovers a "Discard" action (trash over the label, `hazardFill`, 88 pt) and the card rests open; a tap on the action asks (HOME-IPR-08), a tap on the open card closes it without resuming. A swipe past 60 % of the card's width asks straight away and the card springs back. A swipe never deletes on its own. The swipe starts only on a sideways drag, so Home still scrolls (`CardSwipe`, `HorizontalPan`, #211). |

## 4. Players section (List layout: no marquee, 3 or more players)

| ID | Requirement |
|----|-------------|
| HOME-PLY-01 | `SectionHeader` "PLAYERS" with trailing `TextLinkButton` "**All Players**" in the List layout. The One player and Two players layouts use "＋ Add player" instead (HOME-P1-01, HOME-P2-01). The Marquee layout follows HOME-MQ-04. In the Fresh install state there's no trailing action. |
| HOME-PLY-02 | List layout: `CardContainer` with up to 4 `PlayerRow`s (Marquee uses up to 3 below its summary card, HOME-MQ-03): avatar 40, first name (SF Pro 600 16), trailing "HCP" over the handicap index (one decimal), chevron. **No subtitle.** |
| HOME-PLY-03 | Order for the List layout, the Two players layout and the compact rows below a marquee card (the marquee player always comes first, HOME-MQ-01): by the start of each player's most recent round, any round including one in progress (the same rule as `PlayerRepository.recentPlayers`), newest first; then players who haven't played, alphabetical by first name, then full name, ignoring case and accents. ("Last played" on a summary card counts completed rounds only, HOME-PC-02.) |
| HOME-PLY-04 | Tapping a row pushes that player's **Player card**. |
| HOME-PLY-05 | "All Players" pushes **All players**, where new players are added. |
| HOME-PLY-06 | A player with no handicap index shows "—". |

### 4.1 Players empty state (Fresh install)
| ID | Requirement |
|----|-------------|
| HOME-PLY-E1 | A radius-24 `surfaceCard` card (28 / 24 / 24 padding, centered; composed on Home, because `EmptyStateView`'s system layout has no placeholder circle or full-width button): 72 pt `avatarPlaceholder` circle with a person glyph, title "Add your first player" (SF Pro 600 19), body "Start with yourself, then add the people you play with. Their handicaps and scores will show here." (SF Pro 14, `textSecondary`). The copy says "yourself", but no player is flagged as the user. |
| HOME-PLY-E2 | Full-width 50 pt `PrimaryButton` "＋ Add player" opens **Add player**. |

### 4.2 One player (artboard "Home — one player")
| ID | Requirement |
|----|-------------|
| HOME-P1-01 | Shown when the database has **exactly one player and no marquee selection**. `SectionHeader` "**PLAYER**" (singular) with a trailing `TextLinkButton` "＋ Add player" (Lake 600, SF Pro 600 15, plus glyph) that opens **Add player**. There's no "All Players" link. |
| HOME-P1-02 | One `PlayerSummaryCard` (DS-CN-13) **with the handicap chart** (HOME-PC-06…08). The whole card is one button that pushes the player's **Player card**. There's no separate "View player card" button. |
| HOME-P1-03 | With None selected, adding a second player switches Home to the Two players layout on return through observation (HOME-VM-02). With a marquee selected, adding or deleting other players retains the Marquee layout (HOME-MQ-05). |

### 4.3 Two players (artboard "Home — two players")
| ID | Requirement |
|----|-------------|
| HOME-P2-01 | Shown when the database has **exactly two players and no marquee selection**. `SectionHeader` "PLAYERS" with the trailing "＋ Add player" link (as HOME-P1-01). No "All Players" link. |
| HOME-P2-02 | With None selected, two `PlayerSummaryCard`s stacked (gap 8), **without** the handicap chart. Order as HOME-PLY-03: most recently played first, then alphabetical. Each card pushes its player's **Player card**. |
| HOME-P2-03 | With None selected, adding a third player switches Home to the List layout (§4). A selected marquee instead keeps the Marquee layout (§4.5). |

### 4.4 Player summary card (used by §4.2, §4.3 and §4.5)
| ID | Requirement |
|----|-------------|
| HOME-PC-01 | White card (`surfaceCard`), radius 22, 18 pt padding, 1 pt Card Border, 14 pt between its parts. |
| HOME-PC-02 | **Top row:** a 64 pt `PlayerAvatar` (photo, or the initial on the player's color); the player's **full name** (first + last; first only when there's no last name), SF Pro 600 20, one line, truncating; under it "Last played {Nov 8}" (SF Pro 13, Moss 600), or "No rounds yet" if they have no completed round. Trailing: the caps label "HCP INDEX" (SF Pro 600 11, tracking 0.14 em, Moss 600) over the index (SF Pro 700 40, Lake 600), from `HandicapManager` (18-handicap); "—" when there's no index; plus handicaps as "+2.1". |
| HOME-PC-03 | **Stat tiles:** a 3-column grid (gap 8) of `StatTile`s, here with a SF Pro 700 26 value: **Avg score** (one decimal), **Best**, **Last round** (the gross of the most recent completed round). There's no 9 / 18 toggle. *Inferred:* Avg and Best use the hole count this player has more completed rounds of (the Player card's default, PC-ST-06; a tie or none → 18); Last round is the most recent round whatever its hole count. A value with no rounds shows "—". |
| HOME-PC-04 | The card is **one accessibility element** with the button trait: "{Mark Tassinari}, handicap index {8.4}[, calculated], last played {November 8}. Average {78.9}, best {74}, last round {77}." plus, when the chart shows, its summary (HOME-PC-08). |
| HOME-PC-05 | At accessibility text sizes (AX1 and larger) the three tiles stack vertically and the index moves under the name, so nothing truncates. |
| HOME-PC-06 | **Handicap chart (One player and Marquee layouts):** separated by a hairline with 12 pt top padding. Title "HANDICAP · 12 MONTHS" (SF Pro 700 15, tracking 0.06 em) with the trailing range "{11.2} → {8.4}" (SF Pro 12, Moss 600). |
| HOME-PC-07 | A compact Swift Charts `LineMark` + `AreaMark` (Lake 600 line 2.5 pt, Lake 600 @ 10 % area), **70 pt tall**, no gridlines or y axis; the last point has a 4.5 pt Lake 600 dot with a white ring (no value label). Under it three month labels: first, middle, last (DEC / MAY / NOV, SF Pro 12, Moss 600); with only two points, first and last. Data is the same calculated monthly series as the Player card (`HandicapManager.series`, PC-HC-04). |
| HOME-PC-08 | Accessibility summary as PC-HC-05 ("Handicap index fell from 11.2 last December to 8.4 this November"). The chart section is **hidden** when there are fewer than 2 data points (PC-HC-06); the card then ends after the tiles. |
| HOME-PC-09 | `PlayerSummaryBuilder` (pure, shared with the Player card's stats) builds each card's values: `stats(for:rounds:)` gives the full name, last played, the main hole count, Avg / Best / Last round; `chart(_:)` gives the chart points, the range "11.2 → 8.4", the month labels and the chart's accessibility summary (`chartSummary`, HOME-PC-08; nil under 2 points); `accessibilitySummary(_:handicap:chart:)` is the card's HOME-PC-04 label; `homeOrder(_:lastRound:)` is HOME-PLY-03's order. The index itself comes from `HandicapManager`. 100 % unit coverage. |

### 4.5 Marquee player (artboard "one player small cells")

*The marquee selection takes precedence over the count-based layouts, including with two players. None restores §4.1–4.3. This is an explicit change to the original count-only design.*

| ID | Requirement |
|----|-------------|
| HOME-MQ-01 | When a marquee player is selected (DM-PL-11…14), show that player **first** in Players, even if they have never played or fall outside the old four most-recent players. Marquee is a Home display preference, not a "me" flag; it never changes New round selection order, `cardPosition`, leaderboard, scorecard or round-history player order. |
| HOME-MQ-02 | Use the same `PlayerSummaryCard` as One player (DS-CN-13, HOME-PC-01…09), with full name, avatar, last played, index, Avg score / Best / Last round and the 12-month chart. The chart is hidden under two data points. Stats and index keep their existing sources and formatting; tapping the card opens that player's Player card. |
| HOME-MQ-03 | Below the card, show one `CardContainer` of up to **3 compact `PlayerRow`s** (HOME-PLY-02, 04, 06), excluding the marquee player by id, ordered as HOME-PLY-03. Show at most **4 distinct players total**, including the marquee. Hide the compact container when there are no other players. These are compact cells even with exactly two players; there is no second summary card. |
| HOME-MQ-04 | Header uses total player count: 1 → "PLAYER" and "＋ Add player"; 2 → "PLAYERS" and "＋ Add player"; 3+ → "PLAYERS" and "All Players". Actions open their existing destinations. With **None**, use exactly the existing count-based layouts, ordering and actions (§4.1–4.3). |
| HOME-MQ-05 | Selection, clearing, player creation, rename, deletion and imported changes update Home through repository observation (HOME-VM-02). Deleting the marquee leaves None (DM-PL-14). Adding another player never displaces an existing choice or fills an all-false selection while other players remain. |
| HOME-MQ-06 | A marquee summary card means the Recent rounds limit is **3**, with or without an in-progress round (HOME-RR-02). With None selected, preserve the current recent-round limits. |

## 5. Recent rounds section

| ID | Requirement |
|----|-------------|
| HOME-RR-01 | `SectionHeader` "RECENT ROUNDS" with trailing `TextLinkButton` "See all". |
| HOME-RR-02 | `CardContainer` with up to **3** `RoundRow`s of **completed** rounds, newest first, when a round is in progress or the Players section shows summary cards (One player, Two players, Marquee); otherwise up to **4**. |
| HOME-RR-03 | Each row (`RoundRow`, the same design as All rounds) shows: a date block (month caps, e.g. "NOV", over the day number); the course name "Maynard Golf Club" (SF Pro 600 15, one line, truncating) with trailing meta "{9 \| 18} holes · {Tee}" (SF Pro 12, Moss 600); below them one `PlayerScoreChip` per player in round order (a 22 pt avatar dot with the initial or photo, then the gross score in SF Pro 700 16, on a Chalk capsule `#F4F2EA`), wrapping to a second line if needed; and a trailing chevron. |
| HOME-RR-04 | There's **no winner, no "won" text, no weather icon and no to-par** on the row. Every player's gross score is shown; an 18-hole round shows 18-hole totals. |
| HOME-RR-05 | The row height follows its content (14 pt top and bottom padding, 66 pt minimum). Each row is one accessibility element: "{Nov 8}, Maynard Golf Club, {18} holes, {Blue} tees. {Mark} {77}, {Scottie} {75}, …". |
| HOME-RR-06 | Tapping a row pushes **Round detail**. |
| HOME-RR-07 | "See all" pushes **All rounds** (§6), which lists every round in storage. |

### 5.1 Recent rounds empty state
| ID | Requirement |
|----|-------------|
| HOME-RR-E1 | A dashed-border container (1.5 pt dashed, Tee Green border `#C9D6A8` light / `divider` dark, radius 24, no fill): flag icon (Moss 400), title "No rounds yet" (SF Pro 600 16), body "Tap New round to tee off. Finished rounds will be saved here." No action button in the box. The header hides “See all” only when Trash is also empty; while deleted rounds exist, keep that link so Trash remains reachable (#224). |

## 6. All rounds (destination of "See all")

**Artboard:** All rounds.

| ID | Requirement |
|----|-------------|
| HOME-AR-01 | Pushed screen with DSNavigationBar: leading “‹ Home”, centered “ALL ROUNDS”, and a trailing trash icon labeled “Deleted rounds” (`allRounds.trash`). The trash icon remains available when active history is empty and pushes Deleted rounds (#224). Home retains “See all” while Trash is nonempty, even with no recent rounds. |
| HOME-AR-02 | A search field under the bar (44 pt, Chalk 200 `#E9E5D6`, radius 14, magnifier icon, placeholder "Search course or player", accessibility "Search rounds"). Filtering is live, case- and diacritic-insensitive, on the players' first and last names and the course name. There's **no filter control** (no chips, no "I won"). |
| HOME-AR-03 | A count label under the search field: "{n} ROUNDS" ("1 ROUND"), SF Pro 600 13 caps, Moss 600. It counts the rounds shown, so it follows the search. |
| HOME-AR-04 | Lists every **active** round, completed and in progress, newest played first, grouped by month. Native inset-grouped List sections keep RoundRows lazy and support system swipe actions. Trashed records never appear in this history, Home, player history/statistics or handicap calculations (DM-RD-11). |
| HOME-AR-05 | Rows are the Home `RoundRow` (HOME-RR-03…05), except the date block shows the **weekday** caps ("SAT") over the day number, because the month is in the group header. |
| HOME-AR-06 | *Inferred (not drawn):* an in-progress round shows a `StatusPill` "IN PROGRESS" in place of the meta text, and its chips show each player's gross score so far. Tapping it resumes **Hole play**. Tapping a completed round pushes **Round detail**. |
| HOME-AR-07 | Swipe-to-delete asks “Delete this round?” with “The round will be moved to Deleted rounds.”, destructive “Delete round” and Cancel. Completed and in-progress rounds may be moved. Opening/cancelling keeps the native row visible; the swipe trigger is not an optimistic destructive removal. Confirmation marks all stored copies of the logical id in one save and retains their cards. Failure keeps the row/count and shows “The round couldn’t be deleted. Try again.” with OK. Home discard uses the same soft-delete repository rule (DM-RL-02). |
| HOME-AR-08 | A search with no matches shows a dashed box (1.5 pt dashed Tee Green 200, radius 20) with "No rounds match your search". With no rounds at all, the search field and count are hidden and the "No rounds yet" empty state (HOME-RR-E1) shows. |
| HOME-AR-09 | Lazy loading (`LazyVStack` / `List`) so hundreds of rounds stay smooth. |
| HOME-AR-10 | `AllRoundsViewModel` is injected with `RoundRepository`, `CourseProvider`, calendar and locale. It reads all rounds in 200-record pages (including old pages in search and counts), resolves duplicate ids through `round(id:)` so the displayed copy is the same oldest copy navigation opens, and builds snapshots through `RoundSummaryBuilder`; month sections use the shared `RoundMonthGrouping`. It exposes live `query`, sections, count, empty/no-match states, load errors with Retry, and confirmed deletion. A failed load keeps prior data; a loading indicator distinguishes the initial read from an empty store. Repository observation reloads for Round, RoundEntry and Player changes (including local saves, deletions, player renames and imports), and skips empty or unrelated batches. Player photos are decoded and cached on load, then passed to rows as image values; changing search never decodes photos or creates a row photo closure. Filtering and grouping are pure, with 100 % coverage. |

### 6.1 Deleted rounds (#224)

| ID | Requirement |
|----|-------------|
| HOME-TR-01 | Pushed from All rounds’ trash icon. The bar shows “DELETED ROUNDS”, a leading back icon labeled “Back to all rounds”, and a trailing permanent-delete icon labeled “Permanently delete all rounds”. |
| HOME-TR-02 | Shows only trashed rounds, using the same paged, searchable month groups and RoundRow metadata as All rounds. Duplicate logical ids show once (oldest copy). Rows are read-only, with no navigation chevron: they do not resume play or open normal Round detail. |
| HOME-TR-03 | Swiping a row offers “Permanently delete”. It asks “Permanently delete this round?” and explains that all scores will be removed and the action cannot be undone. Cancel retains the row; confirmation permanently deletes every trashed copy of that id and its cards, protecting active records and players. |
| HOME-TR-04 | The top-right action asks “Permanently delete all rounds?” with destructive “Delete all permanently” and Cancel. Confirmation empties **all** Trash, including records outside the current search/page, atomically. Cancel changes nothing. |
| HOME-TR-05 | Empty Trash shows “No deleted rounds”; the permanent-delete-all action is disabled. Active rounds remain untouched when Trash is emptied. |
| HOME-TR-06 | Load failures retain prior rows and offer Try again; failed permanent deletes retain data and show the existing delete error with OK. Store observation follows local changes and imports. |
| HOME-TR-07 | Reuse AllRoundsViewModel with an explicit Trash scope, the injected repository and shared month grouping/photo cache. UI identifiers use `deletedRounds.*`; the screen is `screen.deletedRounds`. |
| HOME-TR-08 | Unit tests cover persistence, filtering, rollback and Trash model behavior. UI tests cover navigation, empty/disabled actions, confirmation/cancel for a row and for all Trash, and preservation of active history. |

## 7. Data and behavior

| ID | Requirement |
|----|-------------|
| HOME-VM-01 | `HomeViewModel` (`@Observable`) is injected with `PlayerRepository`, `RoundRepository`, `SettingsStore`, `HandicapManager` and the `CourseProvider`. It exposes `roundState: .loading / .freshInstall / .noRound / .inProgress([RoundSummary])` (one per round in progress, newest first), `playersLayout` with empty, one, two, list and marquee cases (marquee carries one selected `PlayerStats` and up to 3 other rows; selection takes priority, otherwise use player count; list holds up to 4), `recentRounds`, `hasDeletedRounds`, `courseName` and `showToPar`. Trash presence is a one-record indexed query; it keeps the history link available when active history is empty (#224). Handicaps and the chart come from `HandicapManager` when drawn (`handicap(for:)`, `chart(for:)`), so they update through observation. Two player records sharing an id (a CloudKit duplicate not yet merged, DM-PL-01) show once, as the first record. |
| HOME-VM-02 | The screen refreshes on appear and on every store change: `observe()` reads once, then again for each batch on the repositories' change stream (local saves and iCloud imports alike). The v1 `refreshListener` notification is gone. |
| HOME-VM-03 | Loading state: show placeholder/redacted rows, not a full-screen spinner. |
| HOME-VM-04 | Persistence errors show an inline, localized error banner ("Your rounds couldn't be loaded.") with "Try again" (`refresh()`); what was shown stays. |
| HOME-VM-05 | Round summary logic lives in a pure `RoundSummaryBuilder` (`RoundSummary`) shared with All rounds and the Player card's Previous rounds: the current hole (the first hole not every player has scored; nil once finished) and "Hole {n} of {9 \| 18}", each player's gross total and to-par so far (the shared `RoundEntry.toPar` rule), and the meta text "{18} holes · {Blue}". There's no winner or tie logic. 100 % unit coverage. |

## 8. Accessibility identifiers (for UI tests)
`home.hero`, `home.hero.title`, `home.scroll`, `home.navigationBar`, `navigation.title` (compact title only), `home.settings`, `home.newRound`, `home.newRound.title` (expanded label only), `home.inProgressCard` (one per round), `home.inProgressCard.discard`, `home.discard.confirm`, `home.discardError.ok`, `home.players.allPlayers`, `home.players.addPlayer`, `home.players.row.{id}`, `home.players.card.{id}`, `home.empty.addPlayer`, `home.rounds.seeAll`, `home.rounds.row.{id}`, `home.empty.players`, `home.empty.rounds`, `home.loading`, `home.error`, `home.error.retry`, `allRounds.back`, `allRounds.search`, `allRounds.count`, `allRounds.noResults`, `allRounds.row.{id}`, `allRounds.section.{yyyyMM}`, `allRounds.confirmDelete`, `allRounds.cancelDelete`, `allRounds.delete.{id}`, `allRounds.deleteError.ok`, `allRounds.loading`, `allRounds.error`, `allRounds.retry`.

## 9. Acceptance tests (summary)
- Unit: marquee / None layouts for 0, 1, 2, 3, 4 and 8 players, selected outside the old top four, no duplicated players, compact row order, header actions, recent-round limits and observation; state selection for all three states; players layout for 0, 1, 2, 3 and 8 players (and with a round in progress); summary card values (last played, no rounds, Avg / Best by the player's main hole count, Last round, no index, plus index, chart hidden under 2 points); player ordering; row meta and per-player score chips (1–4 players, 9 / 18 holes); HOLE n OF 9 / 18; multiple in-progress rounds; All rounds search, count label and month grouping.
- UI: Home header actions stay pinned after scrolling; title and New round label compact and expand again at the top (including Dark); both pinned actions navigate correctly. Settings → select marquee → Home shows that card first and compact others; select None → count-based layout returns; picker Back / failed save / Retry and deletion; launch with seeded data for each state and check the visible elements; seed `onePlayer` → one summary card, "Add player", no "All Players" (whether the chart shows is a unit test: the card reads as one element, so the chart has no identifier of its own); seed `twoPlayers` with None selected → two cards, no chart; with None selected, add a third player → the List layout; tap through to Settings, New round, Player card, All players, Round detail, Hole play; See all → All rounds lists every seeded round (completed + in progress); searching a player name narrows the list and the count; no element contains "You" or "won".

