# 11 — All Players

**Artboard:** All players
**Entry:** Home › Players › "All Players".
**Exit:** "‹ Home" (accessibility "Back to home").

## 1. Overview
A searchable list of every player, with handicap index and round count. A trailing "Add" action creates a new player. **This is the entry point for adding players** once at least one exists (Home has no Add button in that state).

## 2. Navigation bar
| ID | Requirement |
|----|-------------|
| AL-NAV-01 | Leading `NeutralPillButton` "‹ Home". |
| AL-NAV-02 | Centered title "Players". |
| AL-NAV-03 | Trailing `TintedButton` "＋ Add" presents **Add player**. The new player appears in the list on return. |

## 3. Search
| ID | Requirement |
|----|-------------|
| AL-SR-01 | A search field with a magnifier icon and placeholder "Search players" (`textSecondary`), always visible above the list: MaynardUI's `DSSearchField` (DS-CN-15). Not `.searchable`: the screen uses `dsNavigationBar`, which hides the system bar `.searchable` draws into. |
| AL-SR-02 | Filtering is live, case- and diacritic-insensitive, on first + last name (`localizedStandardContains`). |
| AL-SR-03 | The count label above the list reads "{n} PLAYERS" with no query and "{k} OF {n} PLAYERS" while filtering. A trailing column header "HCP" sits on the right. |
| AL-SR-04 | No matches → `ContentUnavailableView.search` for the query; VoiceOver reads "No players match “{query}”" (`allPlayers.noResults`). The HCP header hides. |

## 4. List
| ID | Requirement |
|----|-------------|
| AL-LS-01 | An inset-grouped `List` (white rows on the `background`; a `List` gives the system swipe actions) of `PlayerRow`s: avatar, full name, subtitle and trailing handicap + chevron. A calculated index adds "calculated" for VoiceOver (HC-SRC-05). |
| AL-LS-02 | Subtitle: "{n} rounds" for every player (no "You") ("1 round" singular, using a localized plural / String Catalog variation). |
| AL-LS-03 | Handicap "—" when not set. |
| AL-LS-04 | Sort: alphabetical by first name, then last name (`localizedStandardCompare`). |
| AL-LS-05 | Tapping a row pushes that **Player card**. |
| AL-LS-06 | Swipe-to-delete with a destructive confirmation ("Delete {name}?", "Their {n} rounds will also be removed." with a plural variation, no message when they have none). For a player in an active round in progress, or when their rounds can't be read, an alert says why instead. This is in addition to "Delete player" in the Player card's Edit form (05-add-player AP-ED-07); both use the same `PlayerRepository` delete. A failed delete shows an alert. |

## 5. Data
| ID | Requirement |
|----|-------------|
| AL-DT-01 | `AllPlayersViewModel` is injected with `PlayerRepository`, `RoundRepository` (round counts, the in-progress check) and `HandicapManager` (indexes). It exposes `query`, `rows`, `countLabel`, `isEmptyResult`, and reloads on every store change. Filtering and sorting are pure (`static`); the view model is 100 % covered. |
| AL-DT-02 | No players at all → the Home-style empty state with "Add player". |

## 6. Accessibility identifiers
`screen.allPlayers`, `allPlayers.back`, `allPlayers.add`, `allPlayers.search`, `allPlayers.count`, `allPlayers.row.{id}`, `allPlayers.delete.{id}`, `allPlayers.confirmDelete`, `allPlayers.noResults`, `allPlayers.empty.addPlayer`, `allPlayers.retry`.
