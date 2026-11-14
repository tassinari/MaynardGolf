# 01 — Home

**Artboards:** Home (round in progress) · Home — no round in progress · Home — fresh install
**Entry:** App launch (root of `NavigationStack`).

## 1. Overview

Home is the app's root. It shows a photo hero, a card to resume any round in progress, the player list and recent rounds. It has three states, chosen from the data:

| State | Condition | Shows |
|-------|-----------|-------|
| **In progress** | At least one incomplete round exists | Hero, In-progress card, Players, Recent rounds |
| **No round** | Players exist, no incomplete round | Hero, Players, Recent rounds |
| **Fresh install** | No players | Hero, Players empty state, Recent rounds empty state |

The screen background is the `background` token (Chalk 50 / Canopy 950) and scrolls vertically, with 16 pt side gutters and 18 pt between sections.

> **No "me" concept.** The app belongs to whoever is holding the phone. No player is marked as the user. There's no "You" subtitle, no "You won" and no "This is me" flag anywhere in the app.

## 2. Hero header

| ID | Requirement |
|----|-------------|
| HOME-HDR-01 | 230 pt tall full-bleed header that ignores the top safe area. Background is the course photo (green with a white pin flag and autumn trees), aspect-fill, focal point at about 68 % x. Accessibility description: "Golf green with a white pin flag and autumn trees". |
| HOME-HDR-02 | A vertical gradient overlay (Canopy 35 % at top → clear at 30–50 % → Canopy 75 % at bottom) keeps the controls and title readable. In Dark mode the photo is also dimmed (DS-MT-05). |
| HOME-HDR-03 | Top-left: 44 pt `GlassIconButton` with a gear icon, accessibility label "Settings". Tapping it pushes **Settings**. |
| HOME-HDR-04 | Top-right: `GlassPillButton` "＋ New round". Tapping it presents **New round** full-screen. |
| HOME-HDR-05 | Bottom-left title "Maynard Golf" in Title XL (Sofia 700 44), Chalk, with a text shadow. |
| HOME-HDR-06 | *Inferred:* the hero image comes from the course model (per-course hero) and falls back to a bundled asset. |
| HOME-HDR-07 | "New round" always works, even while a round is in progress. **Two (or more) rounds in progress at once are allowed**; there's no warning. |

## 3. In-progress round card (state: In progress)

| ID | Requirement |
|----|-------------|
| HOME-IPR-01 | `surfaceCard` card, radius 24, 20 pt padding, 1 pt border. The whole card is one button (accessibility label "Resume round in progress"). |
| HOME-IPR-02 | Top row: `StatusPill` "IN PROGRESS" (left) and "HOLE {n} OF {9 \| 18}" caps label in `textSecondary` (right). `n` = the first hole where not every player has a score. The total is the round's hole count (chosen at New round). |
| HOME-IPR-03 | A 4-column grid with one column per player in the round, in order: 48 pt `PlayerAvatar`, first name (Inter 600 14), `ToParText` (Sofia 700 20) for holes completed. |
| HOME-IPR-04 | Under-par values use `underPar` (Flag 650 light / Flag 400 dark). Even ("E") and over-par use `textSecondary`. When Settings › "Show to-par scores" is off, show gross totals instead. |
| HOME-IPR-05 | Full-width 50 pt `PrimaryButton` "Resume round" (visual only; the whole card is the hit target). |
| HOME-IPR-06 | Tapping it pushes **Hole play** at the current hole. |
| HOME-IPR-07 | With several incomplete rounds, Home shows **one In-progress card per round** in a vertical list (gap 12), newest first. Each card resumes its own round. They also appear in **All rounds** with an "In progress" pill. |
| HOME-IPR-08 | *Inferred:* long-press offers "Discard round" with a destructive confirmation. |

## 4. Players section

| ID | Requirement |
|----|-------------|
| HOME-PLY-01 | `SectionHeader` "PLAYERS" with trailing `TextLinkButton` "**All Players**" in both the In progress and No round states. In the Fresh install state there's no trailing action. |
| HOME-PLY-02 | `CardContainer` with up to 4 `PlayerRow`s: avatar 40, first name (Inter 600 16), trailing "HCP" over the handicap index (one decimal), chevron. **No subtitle.** |
| HOME-PLY-03 | Order: most recently played first, then alphabetical by first name for players who haven't played yet. |
| HOME-PLY-04 | Tapping a row pushes that player's **Player card**. |
| HOME-PLY-05 | "All Players" pushes **All players**, where new players are added. |
| HOME-PLY-06 | A player with no handicap index shows "—". |

### 4.1 Players empty state (Fresh install)
| ID | Requirement |
|----|-------------|
| HOME-PLY-E1 | `EmptyStateView` in a radius-24 card (28 / 24 / 24 padding, centered): 72 pt `avatarPlaceholder` circle with a person glyph, title "Add your first player" (Inter 600 19), body "Start with yourself, then add the people you play with. Their handicaps and scores will show here." (Inter 14, `textSecondary`). The copy says "yourself", but no player is flagged as the user. |
| HOME-PLY-E2 | Full-width 50 pt `PrimaryButton` "＋ Add player" opens **Add player**. |

## 5. Recent rounds section

| ID | Requirement |
|----|-------------|
| HOME-RR-01 | `SectionHeader` "RECENT ROUNDS" with trailing `TextLinkButton` "See all". |
| HOME-RR-02 | `CardContainer` with up to 3 (In progress) or 4 (No round) `RoundRow`s of **completed** rounds, newest first. |
| HOME-RR-03 | Each row (`RoundRow`, the same design as All rounds) shows: a date block (month caps, e.g. "NOV", over the day number); the course name "Maynard Golf Club" (Inter 600 15, one line, truncating) with trailing meta "{9 \| 18} holes · {Tee}" (Inter 12, Moss 600); below them one `PlayerScoreChip` per player in round order (a 22 pt avatar dot with the initial or photo, then the gross score in Sofia 700 16, on a Chalk capsule `#F4F2EA`), wrapping to a second line if needed; and a trailing chevron. |
| HOME-RR-04 | There's **no winner, no "won" text, no weather icon and no to-par** on the row. Every player's gross score is shown; an 18-hole round shows 18-hole totals. |
| HOME-RR-05 | The row height follows its content (14 pt top and bottom padding, 66 pt minimum). Each row is one accessibility element: "{Nov 8}, Maynard Golf Club, {18} holes, {Blue} tees. {Mark} {77}, {Scottie} {75}, …". |
| HOME-RR-06 | Tapping a row pushes **Round detail**. |
| HOME-RR-07 | "See all" pushes **All rounds** (§6), which lists every round in storage. |

### 5.1 Recent rounds empty state
| ID | Requirement |
|----|-------------|
| HOME-RR-E1 | A dashed-border container (1.5 pt dashed, Tee Green border `#C9D6A8` light / `divider` dark, radius 24, no fill): flag icon (Moss 400), title "No rounds yet" (Inter 600 16), body "Tap New round to tee off. Finished rounds will be saved here." No action button and no "See all". |

## 6. All rounds (destination of "See all")

**Artboard:** All rounds.

| ID | Requirement |
|----|-------------|
| HOME-AR-01 | Pushed screen with `DSNavigationBar`: leading "‹ Home" (accessibility "Back to home"), centered title "ALL ROUNDS". |
| HOME-AR-02 | A search field under the bar (44 pt, Chalk 200 `#E9E5D6`, radius 14, magnifier icon, placeholder "Search course or player", accessibility "Search rounds"). Filtering is live, case- and diacritic-insensitive, on the players' first and last names and the course name. There's **no filter control** (no chips, no "I won"). |
| HOME-AR-03 | A count label under the search field: "{n} ROUNDS" ("1 ROUND"), Sofia 600 13 caps, Moss 600. It counts the rounds shown, so it follows the search. |
| HOME-AR-04 | Lists **every round in storage**, completed and in progress, newest first, grouped by month. Each group has a header ("NOVEMBER 2026", Sofia 700 17, tracking 0.08 em) and a `CardContainer` (radius 20) of `RoundRow`s separated by hairlines. |
| HOME-AR-05 | Rows are the Home `RoundRow` (HOME-RR-03…05), except the date block shows the **weekday** caps ("SAT") over the day number, because the month is in the group header. |
| HOME-AR-06 | *Inferred (not drawn):* an in-progress round shows a `StatusPill` "IN PROGRESS" in place of the meta text, and its chips show each player's gross score so far. Tapping it resumes **Hole play**. Tapping a completed round pushes **Round detail**. |
| HOME-AR-07 | *Not drawn:* swipe-to-delete with a destructive confirmation ("Delete this round? Scores for all {n} players will be removed."). This is the **only** place a round is deleted (Round detail has no delete). In-progress rounds can be deleted too. |
| HOME-AR-08 | A search with no matches shows a dashed box (1.5 pt dashed Tee Green 200, radius 20) with "No rounds match your search". With no rounds at all, the search field and count are hidden and the "No rounds yet" empty state (HOME-RR-E1) shows. |
| HOME-AR-09 | Lazy loading (`LazyVStack` / `List`) so hundreds of rounds stay smooth. |
| HOME-AR-10 | `AllRoundsViewModel` is injected with `RoundRepository`. It exposes `query`, month sections, row models and `countLabel`. Searching, grouping and row-model building are pure, with 100 % coverage. |

## 7. Data and behavior

| ID | Requirement |
|----|-------------|
| HOME-VM-01 | `HomeViewModel` (`@Observable`) is injected with `PlayerRepository`, `RoundRepository`, `SettingsStore` and a `Clock`. It exposes `state: .loading / .freshInstall / .noRound / .inProgress(RoundSummary)` plus `players` and `recentRounds`. |
| HOME-VM-02 | The screen refreshes on appear and after a round finishes. The v1 `refreshListener` notification is replaced by SwiftData `@Query` or observation. |
| HOME-VM-03 | Loading state: show placeholder/redacted rows, not a full-screen spinner. |
| HOME-VM-04 | Persistence errors show an inline, localized error banner with "Try again". |
| HOME-VM-05 | Round summary logic (current hole, hole count 9 / 18, each player's gross total and to-par, row meta text) lives in a pure `RoundSummaryBuilder` shared with All rounds and the Player card. There's no winner or tie logic. 100 % unit coverage. |

## 8. Accessibility identifiers (for UI tests)
`home.settings`, `home.newRound`, `home.inProgressCard`, `home.players.allPlayers`, `home.players.row.{id}`, `home.empty.addPlayer`, `home.rounds.seeAll`, `home.rounds.row.{id}`, `home.empty.players`, `home.empty.rounds`, `allRounds.back`, `allRounds.search`, `allRounds.count`, `allRounds.noResults`, `allRounds.row.{id}`, `allRounds.section.{yyyy-MM}`.

## 9. Acceptance tests (summary)
- Unit: state selection for all three states; player ordering; row meta and per-player score chips (1–4 players, 9 / 18 holes); HOLE n OF 9 / 18; multiple in-progress rounds; All rounds search, count label and month grouping.
- UI: launch with seeded data for each state and check the visible elements; tap through to Settings, New round, Player card, All players, Round detail, Hole play; See all → All rounds lists every seeded round (completed + in progress); searching a player name narrows the list and the count; no element contains "You" or "won".

