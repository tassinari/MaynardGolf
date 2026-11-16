# 01 — Home

**Artboards:** Home (round in progress) · Home — no round in progress · Home — one player · Home — two players · Home — fresh install
**Entry:** App launch (root of `NavigationStack`).

## 1. Overview

Home is the app's root. It shows a photo hero, a card to resume any round in progress, the player list and recent rounds. Two things are chosen from the data, independently: whether a round is in progress, and how the Players section is laid out.

| Round state | Condition | Shows |
|-------|-----------|-------|
| **In progress** | At least one incomplete round exists | Hero, In-progress card(s), Players, Recent rounds |
| **No round** | Players exist, no incomplete round | Hero, Players, Recent rounds |
| **Fresh install** | No players | Hero, Players empty state, Recent rounds empty state |

| Players layout | Number of players in the database | Players section |
|-------|-----------|-------|
| **Empty** | 0 | Empty state (§4.1) |
| **One player** | 1 | Header "PLAYER" + one large player summary card **with** a 12-month handicap chart (§4.2) |
| **Two players** | 2 | Header "PLAYERS" + two player summary cards **without** the chart, stacked (§4.3) |
| **List** | 3 or more | Header "PLAYERS" + the standard list of up to 4 player rows (§4) |

The players layout depends **only** on the player count, not on whether a round is in progress: with one or two players and a round in progress, the In-progress card(s) sit above the summary card(s).

The screen background is the `background` token (Chalk 50 / Canopy 950) and scrolls vertically, with 16 pt side gutters and 18 pt between sections.

> **No "me" concept.** The app belongs to whoever is holding the phone. No player is marked as the user. There's no "You" subtitle, no "You won" and no "This is me" flag anywhere in the app.

## 2. Hero header

| ID | Requirement |
|----|-------------|
| HOME-HDR-01 | 230 pt tall full-bleed header that ignores the top safe area. Background is the course photo (green with a white pin flag and autumn trees), aspect-fill, focal point at about 68 % x. Accessibility description: "Golf green with a white pin flag and autumn trees". |
| HOME-HDR-02 | A vertical gradient overlay (Canopy 35 % at top → clear at 30–50 % → Canopy 75 % at bottom) keeps the controls and title readable. In Dark mode the photo is also dimmed (DS-MT-05). |
| HOME-HDR-03 | Top-left: 44 pt `GlassIconButton` with a gear icon, accessibility label "Settings". Tapping it pushes **Settings**. |
| HOME-HDR-04 | Top-right: `GlassPillButton` "＋ New round". Tapping it presents **New round** full-screen. |
| HOME-HDR-05 | Bottom-left title "Maynard Golf" in Title XL (SF Pro 700 44), Chalk, with a text shadow. |
| HOME-HDR-06 | The hero is the bundled `HomeHero` photo (`HomeViewModel.heroImageName`). The course data has no per-course hero yet; when it gets one, this bundled photo stays the fallback. |
| HOME-HDR-07 | "New round" always works, even while a round is in progress. **Two (or more) rounds in progress at once are allowed**; there's no warning. |

## 3. In-progress round card (state: In progress)

| ID | Requirement |
|----|-------------|
| HOME-IPR-01 | `surfaceCard` card, radius 24, 20 pt padding, 1 pt border. The whole card is one button (accessibility label "Resume round in progress", value "Hole {n} of {9 \| 18}"). |
| HOME-IPR-02 | Top row: `StatusPill` "IN PROGRESS" (left) and "HOLE {n} OF {9 \| 18}" caps label in `textSecondary` (right). `n` = the first hole where not every player has a score. The total is the round's hole count (chosen at New round). |
| HOME-IPR-03 | A 4-column grid with one column per player in the round, in order: 48 pt `PlayerAvatar`, first name (SF Pro 600 14), `ToParText` (SF Pro 700 20) for holes completed. |
| HOME-IPR-04 | Under-par values use `underPar` (Flag 650 light / Flag 400 dark). Even ("E") and over-par use `textSecondary`. When Settings › "Show to-par scores" is off, show gross totals instead. |
| HOME-IPR-05 | Full-width 50 pt `PrimaryButton` "Resume round" (visual only; the whole card is the hit target). |
| HOME-IPR-06 | Tapping it pushes **Hole play** at the current hole. |
| HOME-IPR-07 | With several incomplete rounds, Home shows **one In-progress card per round** in a vertical list (gap 12), newest first. Each card resumes its own round. They also appear in **All rounds** with an "In progress" pill. |
| HOME-IPR-08 | Long-press offers "Discard round". It asks first ("Discard this round?", "The scores entered so far will be deleted.", destructive "Discard round"), then deletes the round and Home redraws. A delete that fails keeps the card and shows the banner "The round couldn't be discarded." (X-11). |

## 4. Players section (List layout: 3 or more players)

| ID | Requirement |
|----|-------------|
| HOME-PLY-01 | `SectionHeader` "PLAYERS" with trailing `TextLinkButton` "**All Players**" in the List layout. The One player and Two players layouts use "＋ Add player" instead (HOME-P1-01, HOME-P2-01). In the Fresh install state there's no trailing action. |
| HOME-PLY-02 | `CardContainer` with up to 4 `PlayerRow`s: avatar 40, first name (SF Pro 600 16), trailing "HCP" over the handicap index (one decimal), chevron. **No subtitle.** |
| HOME-PLY-03 | Order: by the start of each player's most recent round, any round including one in progress (the same rule as `PlayerRepository.recentPlayers`), newest first; then players who haven't played, alphabetical by first name, then full name, ignoring case and accents. ("Last played" on a summary card counts completed rounds only, HOME-PC-02.) |
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
| HOME-P1-01 | Shown when the database has **exactly one player**. `SectionHeader` "**PLAYER**" (singular) with a trailing `TextLinkButton` "＋ Add player" (Lake 600, SF Pro 600 15, plus glyph) that opens **Add player**. There's no "All Players" link. |
| HOME-P1-02 | One `PlayerSummaryCard` (DS-CN-13) **with the handicap chart** (HOME-PC-06…08). The whole card is one button that pushes the player's **Player card**. There's no separate "View player card" button. |
| HOME-P1-03 | Adding a second player switches Home to the Two players layout on return, through observation (HOME-VM-02); deleting players switches back the same way. |

### 4.3 Two players (artboard "Home — two players")
| ID | Requirement |
|----|-------------|
| HOME-P2-01 | Shown when the database has **exactly two players**. `SectionHeader` "PLAYERS" with the trailing "＋ Add player" link (as HOME-P1-01). No "All Players" link. |
| HOME-P2-02 | Two `PlayerSummaryCard`s stacked (gap 8), **without** the handicap chart. Order as HOME-PLY-03: most recently played first, then alphabetical. Each card pushes its player's **Player card**. |
| HOME-P2-03 | Adding a third player switches Home to the List layout (§4). |

### 4.4 Player summary card (used by §4.2 and §4.3)
| ID | Requirement |
|----|-------------|
| HOME-PC-01 | White card (`surfaceCard`), radius 22, 18 pt padding, 1 pt Card Border, 14 pt between its parts. |
| HOME-PC-02 | **Top row:** a 64 pt `PlayerAvatar` (photo, or the initial on the player's color); the player's **full name** (first + last; first only when there's no last name), SF Pro 600 20, one line, truncating; under it "Last played {Nov 8}" (SF Pro 13, Moss 600), or "No rounds yet" if they have no completed round. Trailing: the caps label "HCP INDEX" (SF Pro 600 11, tracking 0.14 em, Moss 600) over the index (SF Pro 700 40, Lake 600), from `HandicapManager` (18-handicap); "—" when there's no index; plus handicaps as "+2.1". |
| HOME-PC-03 | **Stat tiles:** a 3-column grid (gap 8) of `StatTile`s, here with a SF Pro 700 26 value: **Avg score** (one decimal), **Best**, **Last round** (the gross of the most recent completed round). There's no 9 / 18 toggle. *Inferred:* Avg and Best use the hole count this player has more completed rounds of (the Player card's default, PC-ST-06; a tie or none → 18); Last round is the most recent round whatever its hole count. A value with no rounds shows "—". |
| HOME-PC-04 | The card is **one accessibility element** with the button trait: "{Mark Tassinari}, handicap index {8.4}[, calculated], last played {November 8}. Average {78.9}, best {74}, last round {77}." plus, when the chart shows, its summary (HOME-PC-08). |
| HOME-PC-05 | At accessibility text sizes (AX1 and larger) the three tiles stack vertically and the index moves under the name, so nothing truncates. |
| HOME-PC-06 | **Handicap chart (One player only):** separated by a hairline with 12 pt top padding. Title "HANDICAP · 12 MONTHS" (SF Pro 700 15, tracking 0.06 em) with the trailing range "{11.2} → {8.4}" (SF Pro 12, Moss 600). |
| HOME-PC-07 | A compact Swift Charts `LineMark` + `AreaMark` (Lake 600 line 2.5 pt, Lake 600 @ 10 % area), **70 pt tall**, no gridlines or y axis; the last point has a 4.5 pt Lake 600 dot with a white ring (no value label). Under it three month labels: first, middle, last (DEC / MAY / NOV, SF Pro 12, Moss 600); with only two points, first and last. Data is the same calculated monthly series as the Player card (`HandicapManager.series`, PC-HC-04). |
| HOME-PC-08 | Accessibility summary as PC-HC-05 ("Handicap index fell from 11.2 last December to 8.4 this November"). The chart section is **hidden** when there are fewer than 2 data points (PC-HC-06); the card then ends after the tiles. |
| HOME-PC-09 | `PlayerSummaryBuilder` (pure, shared with the Player card's stats) builds each card's values: `stats(for:rounds:)` gives the full name, last played, the main hole count, Avg / Best / Last round; `chart(_:)` gives the chart points, the range "11.2 → 8.4", the month labels and the chart's accessibility summary (`chartSummary`, HOME-PC-08; nil under 2 points); `accessibilitySummary(_:handicap:chart:)` is the card's HOME-PC-04 label; `homeOrder(_:lastRound:)` is HOME-PLY-03's order. The index itself comes from `HandicapManager`. 100 % unit coverage. |

## 5. Recent rounds section

| ID | Requirement |
|----|-------------|
| HOME-RR-01 | `SectionHeader` "RECENT ROUNDS" with trailing `TextLinkButton` "See all". |
| HOME-RR-02 | `CardContainer` with up to **3** `RoundRow`s of **completed** rounds, newest first, when a round is in progress or the Players section shows summary cards (One player, Two players); otherwise up to **4**. |
| HOME-RR-03 | Each row (`RoundRow`, the same design as All rounds) shows: a date block (month caps, e.g. "NOV", over the day number); the course name "Maynard Golf Club" (SF Pro 600 15, one line, truncating) with trailing meta "{9 \| 18} holes · {Tee}" (SF Pro 12, Moss 600); below them one `PlayerScoreChip` per player in round order (a 22 pt avatar dot with the initial or photo, then the gross score in SF Pro 700 16, on a Chalk capsule `#F4F2EA`), wrapping to a second line if needed; and a trailing chevron. |
| HOME-RR-04 | There's **no winner, no "won" text, no weather icon and no to-par** on the row. Every player's gross score is shown; an 18-hole round shows 18-hole totals. |
| HOME-RR-05 | The row height follows its content (14 pt top and bottom padding, 66 pt minimum). Each row is one accessibility element: "{Nov 8}, Maynard Golf Club, {18} holes, {Blue} tees. {Mark} {77}, {Scottie} {75}, …". |
| HOME-RR-06 | Tapping a row pushes **Round detail**. |
| HOME-RR-07 | "See all" pushes **All rounds** (§6), which lists every round in storage. |

### 5.1 Recent rounds empty state
| ID | Requirement |
|----|-------------|
| HOME-RR-E1 | A dashed-border container (1.5 pt dashed, Tee Green border `#C9D6A8` light / `divider` dark, radius 24, no fill): flag icon (Moss 400), title "No rounds yet" (SF Pro 600 16), body "Tap New round to tee off. Finished rounds will be saved here." No action button and no "See all". |

## 6. All rounds (destination of "See all")

**Artboard:** All rounds.

| ID | Requirement |
|----|-------------|
| HOME-AR-01 | Pushed screen with `DSNavigationBar`: leading "‹ Home" (accessibility "Back to home"), centered title "ALL ROUNDS". |
| HOME-AR-02 | A search field under the bar (44 pt, Chalk 200 `#E9E5D6`, radius 14, magnifier icon, placeholder "Search course or player", accessibility "Search rounds"). Filtering is live, case- and diacritic-insensitive, on the players' first and last names and the course name. There's **no filter control** (no chips, no "I won"). |
| HOME-AR-03 | A count label under the search field: "{n} ROUNDS" ("1 ROUND"), SF Pro 600 13 caps, Moss 600. It counts the rounds shown, so it follows the search. |
| HOME-AR-04 | Lists **every round in storage**, completed and in progress, newest first, grouped by month. Each group has a header ("NOVEMBER 2026", SF Pro 700 17, tracking 0.08 em) and a `CardContainer` (radius 20) of `RoundRow`s separated by hairlines. |
| HOME-AR-05 | Rows are the Home `RoundRow` (HOME-RR-03…05), except the date block shows the **weekday** caps ("SAT") over the day number, because the month is in the group header. |
| HOME-AR-06 | *Inferred (not drawn):* an in-progress round shows a `StatusPill` "IN PROGRESS" in place of the meta text, and its chips show each player's gross score so far. Tapping it resumes **Hole play**. Tapping a completed round pushes **Round detail**. |
| HOME-AR-07 | *Not drawn:* swipe-to-delete with a destructive confirmation ("Delete this round? Scores for all {n} players will be removed."). This is the **only** place a round is deleted (Round detail has no delete). In-progress rounds can be deleted too. |
| HOME-AR-08 | A search with no matches shows a dashed box (1.5 pt dashed Tee Green 200, radius 20) with "No rounds match your search". With no rounds at all, the search field and count are hidden and the "No rounds yet" empty state (HOME-RR-E1) shows. |
| HOME-AR-09 | Lazy loading (`LazyVStack` / `List`) so hundreds of rounds stay smooth. |
| HOME-AR-10 | `AllRoundsViewModel` is injected with `RoundRepository`. It exposes `query`, month sections, row models and `countLabel`. Searching, grouping and row-model building are pure, with 100 % coverage. |

## 7. Data and behavior

| ID | Requirement |
|----|-------------|
| HOME-VM-01 | `HomeViewModel` (`@Observable`) is injected with `PlayerRepository`, `RoundRepository`, `SettingsStore`, `HandicapManager` and the `CourseProvider`. It exposes `roundState: .loading / .freshInstall / .noRound / .inProgress([RoundSummary])` (one per round in progress, newest first), `playersLayout: .empty / .one(PlayerStats) / .two(PlayerStats, PlayerStats) / .list([PlayerStats])` (from the player count only; the list holds up to 4), `recentRounds`, `courseName` and `showToPar`. Handicaps and the chart come from `HandicapManager` when drawn (`handicap(for:)`, `chart(for:)`), so they update through observation. Two player records sharing an id (a CloudKit duplicate not yet merged, DM-PL-01) show once, as the first record. |
| HOME-VM-02 | The screen refreshes on appear and on every store change: `observe()` reads once, then again for each batch on the repositories' change stream (local saves and iCloud imports alike). The v1 `refreshListener` notification is gone. |
| HOME-VM-03 | Loading state: show placeholder/redacted rows, not a full-screen spinner. |
| HOME-VM-04 | Persistence errors show an inline, localized error banner ("Your rounds couldn't be loaded.") with "Try again" (`refresh()`); what was shown stays. |
| HOME-VM-05 | Round summary logic lives in a pure `RoundSummaryBuilder` (`RoundSummary`) shared with All rounds and the Player card's Previous rounds: the current hole (the first hole not every player has scored; nil once finished) and "Hole {n} of {9 \| 18}", each player's gross total and to-par so far (the shared `RoundEntry.toPar` rule), and the meta text "{18} holes · {Blue}". There's no winner or tie logic. 100 % unit coverage. |

## 8. Accessibility identifiers (for UI tests)
`home.hero`, `home.hero.title`, `home.settings`, `home.newRound`, `home.inProgressCard` (one per round), `home.inProgressCard.discard`, `home.discard.confirm`, `home.players.allPlayers`, `home.players.addPlayer`, `home.players.row.{id}`, `home.players.card.{id}`, `home.empty.addPlayer`, `home.rounds.seeAll`, `home.rounds.row.{id}`, `home.empty.players`, `home.empty.rounds`, `home.loading`, `home.error`, `home.error.retry`, `allRounds.back`, `allRounds.search`, `allRounds.count`, `allRounds.noResults`, `allRounds.row.{id}`, `allRounds.section.{yyyy-MM}`.

## 9. Acceptance tests (summary)
- Unit: state selection for all three states; players layout for 0, 1, 2, 3 and 8 players (and with a round in progress); summary card values (last played, no rounds, Avg / Best by the player's main hole count, Last round, no index, plus index, chart hidden under 2 points); player ordering; row meta and per-player score chips (1–4 players, 9 / 18 holes); HOLE n OF 9 / 18; multiple in-progress rounds; All rounds search, count label and month grouping.
- UI: launch with seeded data for each state and check the visible elements; seed `onePlayer` → one summary card, "Add player", no "All Players" (whether the chart shows is a unit test: the card reads as one element, so the chart has no identifier of its own); seed `twoPlayers` → two cards, no chart; add a third player → the List layout; tap through to Settings, New round, Player card, All players, Round detail, Hole play; See all → All rounds lists every seeded round (completed + in progress); searching a player name narrows the list and the count; no element contains "You" or "won".

