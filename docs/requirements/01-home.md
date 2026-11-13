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
| HOME-HDR-07 | *Inferred:* while a round is in progress, "New round" still works. Starting a new one asks: "A round is in progress. Start a new round anyway?" (Keep / Start new). |

## 3. In-progress round card (state: In progress)

| ID | Requirement |
|----|-------------|
| HOME-IPR-01 | `surfaceCard` card, radius 24, 20 pt padding, 1 pt border. The whole card is one button (accessibility label "Resume round in progress"). |
| HOME-IPR-02 | Top row: `StatusPill` "IN PROGRESS" (left) and "HOLE {n} OF {9 \| 18}" caps label in `textSecondary` (right). `n` = the first hole where not every player has a score. The total is the round's hole count (chosen at New round). |
| HOME-IPR-03 | A 4-column grid with one column per player in the round, in order: 48 pt `PlayerAvatar`, first name (Inter 600 14), `ToParText` (Sofia 700 20) for holes completed. |
| HOME-IPR-04 | Under-par values use `underPar` (Flag 650 light / Flag 400 dark). Even ("E") and over-par use `textSecondary`. When Settings › "Show to-par scores" is off, show gross totals instead. |
| HOME-IPR-05 | Full-width 50 pt `PrimaryButton` "Resume round" (visual only; the whole card is the hit target). |
| HOME-IPR-06 | Tapping it pushes **Hole play** at the current hole. |
| HOME-IPR-07 | *Inferred:* if there are several incomplete rounds, show the most recent. Older incomplete rounds appear in **All rounds** with an "In progress" pill and can be resumed from there. |
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
| HOME-RR-03 | Each row shows: month caps (e.g. "NOV") over the day number; course name (Inter 600 15); subtitle "{n} players · {winner first name} won" (ties: "{n} players · Tie"); a `WeatherIcon` for the round's weather; the **winning gross score** (Sofia 700 22) over its `ToParText` (Sofia 600 13, `textSecondary`). |
| HOME-RR-04 | Rounds are listed as **9** or **18** holes. An 18-hole round's score is the 18-hole total. *Inferred:* add "· 9 holes" to the subtitle for 9-hole rounds, e.g. "4 players · 9 holes · Scottie won". |
| HOME-RR-05 | A single-player round reads "1 player · {score}" with no "won". |
| HOME-RR-06 | Tapping a row pushes **Round detail**. |
| HOME-RR-07 | "See all" pushes **All rounds** (§6), which lists every round in storage. |

### 5.1 Recent rounds empty state
| ID | Requirement |
|----|-------------|
| HOME-RR-E1 | A dashed-border container (1.5 pt dashed, Tee Green border `#C9D6A8` light / `divider` dark, radius 24, no fill): flag icon (Moss 400), title "No rounds yet" (Inter 600 16), body "Tap New round to tee off. Finished rounds will be saved here." No action button and no "See all". |

## 6. All rounds (destination of "See all")

There's no wire for this screen. It reuses the Home `RoundRow` and the standard list patterns.

| ID | Requirement |
|----|-------------|
| HOME-AR-01 | Pushed screen with `DSNavigationBar`: leading "‹ Home", centered title "ROUNDS". |
| HOME-AR-02 | Lists **every round in storage**, completed and in progress, newest first, grouped by month (section headers "NOVEMBER 2026" etc.) in `CardContainer`s of `RoundRow`s. |
| HOME-AR-03 | In-progress rounds show a `StatusPill` "IN PROGRESS" in place of the score. Tapping one resumes **Hole play**. Tapping a completed round pushes **Round detail**. |
| HOME-AR-04 | Lazy loading (`LazyVStack` / `List`) so hundreds of rounds stay smooth. |
| HOME-AR-05 | Swipe-to-delete with a destructive confirmation ("Delete this round? Scores for all {n} players will be removed."). This is the **only** place a round is deleted (Round detail has no delete). In-progress rounds can be deleted too. |
| HOME-AR-06 | Empty: the same "No rounds yet" empty state as HOME-RR-E1. |
| HOME-AR-07 | `AllRoundsViewModel` is injected with `RoundRepository`. It exposes month sections and row models. Grouping and row-model building are pure, with 100 % coverage. |

## 7. Data and behavior

| ID | Requirement |
|----|-------------|
| HOME-VM-01 | `HomeViewModel` (`@Observable`) is injected with `PlayerRepository`, `RoundRepository`, `SettingsStore` and a `Clock`. It exposes `state: .loading / .freshInstall / .noRound / .inProgress(RoundSummary)` plus `players` and `recentRounds`. |
| HOME-VM-02 | The screen refreshes on appear, after a round finishes, and after import (`didImport`). The `refreshListener` notification is replaced by SwiftData `@Query` or observation. |
| HOME-VM-03 | Loading state: show placeholder/redacted rows, not a full-screen spinner. |
| HOME-VM-04 | Persistence errors show an inline, localized error banner with "Try again". |
| HOME-VM-05 | Round summary logic (current hole, hole count 9/18, winner/tie, winning score and to-par) lives in a pure `RoundSummaryBuilder` shared with All rounds and the Player card. 100 % unit coverage. |

## 8. Accessibility identifiers (for UI tests)
`home.settings`, `home.newRound`, `home.inProgressCard`, `home.players.allPlayers`, `home.players.row.{id}`, `home.empty.addPlayer`, `home.rounds.seeAll`, `home.rounds.row.{id}`, `home.empty.players`, `home.empty.rounds`, `allRounds.back`, `allRounds.row.{id}`, `allRounds.section.{yyyy-MM}`.

## 9. Acceptance tests (summary)
- Unit: state selection for all three states; player ordering; winner / tie / single-player subtitles; winning score and to-par; HOLE n OF 9 / 18; multiple in-progress rounds; All rounds month grouping.
- UI: launch with seeded data for each state and check the visible elements; tap through to Settings, New round, Player card, All players, Round detail, Hole play; See all → All rounds lists every seeded round (completed + in progress); no element contains "You".

