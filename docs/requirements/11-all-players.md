# 11 — All Players

**Artboard:** All players
**Entry:** Home › Players › "All Players".
**Exit:** "‹ Home" (accessibility "Back to home").

## 1. Overview
A searchable list of every player, with handicap index and round count. A trailing "Add" action creates a new player.

## 2. Navigation bar
| ID | Requirement |
|----|-------------|
| AL-NAV-01 | Leading `NeutralPillButton` "‹ Home". |
| AL-NAV-02 | Centered caps title "PLAYERS". |
| AL-NAV-03 | Trailing `TintedButton` "＋ Add" presents **Add player**. The new player appears in the list on return. |

## 3. Search
| ID | Requirement |
|----|-------------|
| AL-SR-01 | A search field with a magnifier icon and placeholder "Search players" (Moss 400). Use the standard `.searchable` (always visible, `.navigationBarDrawer(displayMode: .always)`), themed. |
| AL-SR-02 | Filtering is live, case- and diacritic-insensitive, on first + last name (`localizedStandardContains`). |
| AL-SR-03 | The count label above the list reads "{n} PLAYERS" with no query and "{k} OF {n} PLAYERS" while filtering. A trailing column header "HCP" sits on the right. |
| AL-SR-04 | No matches → the message "No players match “{query}”" (`ContentUnavailableView.search` style). |

## 4. List
| ID | Requirement |
|----|-------------|
| AL-LS-01 | `CardContainer` of 64 pt `PlayerRow`s: avatar 40, full name, subtitle and trailing handicap (Sofia 700) + chevron. |
| AL-LS-02 | Subtitle: "You · {n} rounds" for the me-player, otherwise "{n} rounds" ("1 round" singular, using a localized plural / String Catalog variation). |
| AL-LS-03 | Handicap "—" when not set. |
| AL-LS-04 | Sort: me first, then alphabetical by first name (`localizedStandardCompare`). |
| AL-LS-05 | Tapping a row pushes that **Player card**. |
| AL-LS-06 | *Inferred:* swipe-to-delete with a destructive confirmation ("Delete {name}? Their {n} rounds will also be removed."). It's blocked for players in a round in progress. |

## 5. Data
| ID | Requirement |
|----|-------------|
| AL-DT-01 | `AllPlayersViewModel` is injected with `PlayerRepository`. It exposes `query`, `rows`, `countLabel`, `isEmptyResult`. Filtering and sorting are pure, with 100 % coverage. |
| AL-DT-02 | No players at all → the Home-style empty state with "Add player". |

## 6. Accessibility identifiers
`allPlayers.back`, `allPlayers.add`, `allPlayers.search`, `allPlayers.count`, `allPlayers.row.{id}`, `allPlayers.noResults`.

## Open questions
1. Is delete wanted here, on the Player card, or both?
