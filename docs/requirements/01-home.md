# 01 — Home

**Artboards:** Home (round in progress) · Home — no round in progress · Home — fresh install
**Entry:** App launch (root of `NavigationStack`).

## 1. Overview

Home is the app's root. It shows a photo hero, a card to resume any round in progress, the player list and recent rounds. It has three states, chosen from the data:

| State | Condition | Shows |
|-------|-----------|-------|
| **In progress** | At least one incomplete round exists | Hero, In-progress card, Players, Recent rounds |
| **No round** | Players exist, no incomplete round | Hero, Players (with "Add player"), Recent rounds |
| **Fresh install** | No players | Hero, Players empty state, Recent rounds empty state |

The screen background is Chalk 50 and scrolls vertically, with 16 pt side gutters and 18 pt between sections.

## 2. Hero header

| ID | Requirement |
|----|-------------|
| HOME-HDR-01 | 230 pt tall full-bleed header that ignores the top safe area. Background is the course photo (green with a white pin flag and autumn trees), aspect-fill, focal point at about 68 % x. Accessibility description: "Golf green with a white pin flag and autumn trees". |
| HOME-HDR-02 | A vertical gradient overlay (Canopy 35 % at top → clear at 30–50 % → Canopy 75 % at bottom) keeps the controls and title readable. |
| HOME-HDR-03 | Top-left: 44 pt `GlassIconButton` with a gear icon, accessibility label "Settings". Tapping it pushes **Settings**. |
| HOME-HDR-04 | Top-right: `GlassPillButton` "＋ New round". Tapping it presents **New round** full-screen. |
| HOME-HDR-05 | Bottom-left title "Maynard Golf" in Title XL (Sofia 700 44), Chalk, with a text shadow. |
| HOME-HDR-06 | *Inferred:* the hero image comes from the course model (per-course hero) and falls back to a bundled asset. |
| HOME-HDR-07 | *Inferred:* while a round is in progress, "New round" still works. Starting a new one asks: "You have a round in progress. Start a new round anyway?" (Keep / Start new). |

## 3. In-progress round card (state: In progress)

| ID | Requirement |
|----|-------------|
| HOME-IPR-01 | White card, radius 24, 20 pt padding, 1 pt border. The whole card is one button (accessibility label "Resume round in progress"). |
| HOME-IPR-02 | Top row: `StatusPill` "IN PROGRESS" (left) and "HOLE {n} OF {total}" caps label in Moss 600 (right). `n` = the first hole without all scores in. |
| HOME-IPR-03 | A 4-column grid with one column per player in the round, in order: 48 pt `PlayerAvatar`, first name (Inter 600 14), `ToParText` (Sofia 700 20) for holes completed. |
| HOME-IPR-04 | Under-par values use Flag 650. Even ("E") and over-par use Moss 600. |
| HOME-IPR-05 | Full-width 50 pt `PrimaryButton` "Resume round" (visual only; the whole card is the hit target). |
| HOME-IPR-06 | Tapping it pushes **Hole play** at the current hole. |
| HOME-IPR-07 | *Inferred:* if there are several incomplete rounds, show the most recent. An older one can be resumed from Recent rounds (open question). |
| HOME-IPR-08 | *Inferred:* long-press offers "Discard round" with a destructive confirmation. |

## 4. Players section

| ID | Requirement |
|----|-------------|
| HOME-PLY-01 | `SectionHeader` "PLAYERS". Trailing action: **In progress** state → `TextLinkButton` "All Players". **No round** state → "Add player" button. (Open question: unify these.) |
| HOME-PLY-02 | `CardContainer` with up to 4 `PlayerRow`s: avatar 40, first name, optional subtitle "You" for the player flagged *This is me*, trailing "HCP" over the handicap index (one decimal), chevron. |
| HOME-PLY-03 | Order: the "me" player first, then most recently played. |
| HOME-PLY-04 | Tapping a row pushes that player's **Player card**. |
| HOME-PLY-05 | "All Players" pushes **All players**. "Add player" presents **Add player**. |
| HOME-PLY-06 | A player with no handicap index shows "—". |

### 4.1 Players empty state (Fresh install)
| ID | Requirement |
|----|-------------|
| HOME-PLY-E1 | `EmptyStateView` inside the card: person icon, title "Add your first player", body "Start with yourself, then add the people you play with. Their handicaps and scores will show here." |
| HOME-PLY-E2 | `TintedButton` "＋ Add player" opens **Add player**. "This is me" is preset to on when no "me" player exists. |

## 5. Recent rounds section

| ID | Requirement |
|----|-------------|
| HOME-RR-01 | `SectionHeader` "RECENT ROUNDS" with trailing `TextLinkButton` "See all". |
| HOME-RR-02 | `CardContainer` with up to 3 (In progress) or 4 (No round) `RoundRow`s, newest first. Only **completed** rounds are listed. |
| HOME-RR-03 | Each row shows: month caps (e.g. "NOV") over the day number; course name (Inter 600 15); subtitle "{n} players · {winner} won", where the winner is "You" if the me-player won; a `WeatherIcon` for the round's weather; gross score (Sofia 700 22) over `ToParText` (Sofia 600 13, Moss 600). |
| HOME-RR-04 | Score and to-par are the **me-player's**. If "me" didn't play, show the winner's. (Open question.) |
| HOME-RR-05 | Ties: subtitle reads "{n} players · Tie". |
| HOME-RR-06 | Tapping a row pushes **Round detail**. |
| HOME-RR-07 | "See all" pushes the me-player's **Player card** scrolled to Previous rounds (as the visual links). Open question: a dedicated "All rounds" list may suit better. |

### 5.1 Recent rounds empty state
| ID | Requirement |
|----|-------------|
| HOME-RR-E1 | Flag icon, title "No rounds yet", body "Tap New round to tee off. Finished rounds will be saved here." No action button. |

## 6. Data and behavior

| ID | Requirement |
|----|-------------|
| HOME-VM-01 | `HomeViewModel` (`@Observable`) is injected with `PlayerRepository`, `RoundRepository` and a `Clock`. It exposes `state: .loading / .freshInstall / .noRound / .inProgress(RoundSummary)` plus `players` and `recentRounds`. |
| HOME-VM-02 | The screen refreshes on appear, after a round finishes, and after import (`didImport`). The `refreshListener` notification is replaced by SwiftData `@Query` or observation. |
| HOME-VM-03 | Loading state: show placeholder/redacted rows, not a full-screen spinner. |
| HOME-VM-04 | Persistence errors show an inline, localized error banner with "Try again". |

## 7. Accessibility identifiers (for UI tests)
`home.settings`, `home.newRound`, `home.inProgressCard`, `home.players.allPlayers`, `home.players.add`, `home.players.row.{id}`, `home.rounds.seeAll`, `home.rounds.row.{id}`, `home.empty.players`, `home.empty.rounds`.

## 8. Acceptance tests (summary)
- Unit: state selection for all three states, player ordering, winner/tie text, to-par formatting, HOLE n OF N calculation, multiple in-progress rounds.
- UI: launch with seeded data for each state and check the visible elements; tap through to Settings, New round, Player card, All players, Round detail, Hole play.

## Open questions
1. Players header action differs between states ("All Players" vs "Add player"). Show both?
2. Maynard GC has 9 holes, but the design says "HOLE 2 OF 18". Is a round 9 holes, 18 (played twice), or chosen at New round?
3. Whose score shows in Recent rounds when "me" didn't play?
4. Should "See all" open a dedicated rounds list rather than the player card?
