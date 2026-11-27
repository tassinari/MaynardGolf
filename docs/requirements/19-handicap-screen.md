# 19 — Handicap screen, Add score and Add course

**Artboards:** Handicap, Add score, Add course; the profile card and Handicap History in Player card — score graph.
**Entry:** Player card › profile card or Handicap History (09-player-card PC-HDR-06, PC-HC-07) › Handicap › Add score › Add course. Each is pushed with a back circle.
**Story:** [#253](https://github.com/tassinari/MaynardGolf/issues/253); the data is [#252](https://github.com/tassinari/MaynardGolf/issues/252) (12-data-model §3.4, §3.5).

## 1. Overview
A player's handicap with the rounds behind it, and a way to add scores shot at other courses so they count too. Maynard rounds are counted automatically from the rounds played in the app; outside courses and their scores are entered by hand. The index, the list and which rounds count all come from `HandicapManager` (18-handicap HC-MG-01, 08), so every screen shows the same number.

## 2. Handicap
| ID | Requirement |
|----|-------------|
| HS-TOP-01 | Leading 44 pt back circle ("Back to player card", `handicap.back`), the title "Handicap" leading (`DSNavigationBar`), and a trailing primary pill **Add score** with a plus (`handicap.addScore`), which pushes Add score. |
| HS-HDR-01 | A white `ContentCard`: a 64 pt `PlayerAvatar`, the full name (`cardName`, two lines), and right-aligned "HCP INDEX" over the index (`titleXL`, `emphasis`). |
| HS-HDR-02 | The index is the one every screen shows (calculated, else the starting index, else "—"), with PC-HDR-05's accessibility label (`handicap.index`). |
| HS-HDR-03 | Under a hairline, a sentence from `HandicapExplanation` (pure, 100 %) (`handicap.explanation`): "Your index is the average of the {k} lowest differentials from your {n} most recent rounds." (one differential: "Your index is the lowest differential from your {n} most recent rounds"), with ", minus 2.0" / ", minus 1.0" for the table's adjusted rows (HC-CA-05), then "Rounds that count are highlighted below." Fewer than 3 rounds: "Post {n} more scores to get an index." (plural variants). A starting index with fewer than 3 rounds: "This is the starting index from Edit player. Post {n} more scores to get an index from your rounds." (plural variants, #268). |
| HS-LS-01 | A native inset-grouped list. Its header is "Last 20 rounds", or "Last {n} rounds" with fewer (`handicap.listTitle`), over the column captions SCORE / COURSE / DIFF. |
| HS-LS-02 | The rows are `HandicapManager.breakdown(for:)`: the newest 20 usable rounds and outside scores together, newest first (HC-CA-13). |
| HS-LS-03 | Each row (`HandicapRoundRow`, `handicap.row.{id}`): the gross (`holeStat`); the course name, then the tee for a Maynard round ("Blue") and "9 holes" for a nine ("Blue · 9 holes"; an outside 18-hole score has no second line); the date played in the locale's numeric format (an outside score's stored day read in UTC, DM-OS-04, so it's the date that was picked); and the differential, one decimal. One accessibility element: "Score 77, Cedar Ridge, 11/8/2026, differential 8.2, counts toward index" (or "doesn't count"). |
| HS-LS-04 | The rows that count toward the calculated index have a Blue 50 (`countingHighlight`) background and a bold Blue differential; the others are white with a `textSecondary` differential. |
| HS-LS-05 | Tapping a Maynard row pushes Round detail. Outside rows don't open anything. |
| HS-LS-06 | An outside row has a trailing swipe **Delete score** (`handicap.delete.{id}`, not the destructive role, which would remove the row before the answer). It asks "Delete this score?" with "It won't count toward the handicap any more. This can't be undone." and **Delete score** (`handicap.confirmDelete`); confirming deletes it permanently (DM-OS-09) and the index follows by observation. Maynard rows have no swipe; rounds are deleted in All rounds. A failed delete, or one that finds no score (already deleted on another device, or on a duplicate player copy), shows "The score couldn't be deleted." |
| HS-LS-07 | No rounds and no outside scores: "No scores yet", "Finish a round or add a score from another course." (`handicap.empty`). |
| HS-DT-01 | `HandicapViewModel` (injected `PlayerRepository`, `OutsideScoreRepository`, `HandicapManager`, locale and calendar) reads the player again on every store change; a player who's gone closes the screen (`Router.close(.handicap(id))`). |

## 3. Add score
| ID | Requirement |
|----|-------------|
| HS-AS-01 | Back circle ("Back to handicap", `addScore.back`) and the title "Add score". |
| HS-AS-02 | The intro: "Add scores from other courses to count them toward your handicap." over "Scores from {home course} are added automatically." (the course name from the course data, X-16; the line is left out without it). |
| HS-AS-03 | The fields: **SCORE** (number pad, placeholder 78, `addScore.score`), **DATE** (a date picker, today by the injected clock, no later day, `addScore.date`), **HOLES PLAYED** (`DSSegmented` "9 holes" / "18 holes", 18 by default, `addScore.holes`). There's no tee: an outside course has one rating and slope (DM-OS). |
| HS-AS-04 | **COURSE**: a menu of the outside courses A–Z (`addScore.course`), the newest added chosen by default, and under it a tinted **Add course** button with a plus (`addScore.addCourse`), which pushes Add course. Coming back from a saved course selects it. |
| HS-AS-05 | Only outside courses are listed: Maynard scores come from rounds, so posting one here would count it twice. With none yet the menu reads "Add a course first" (`addScore.noCourses`). A failed read shows "The courses couldn't be loaded." in the course card instead, with **Try again** (`addScore.loadError`, `addScore.reloadCourses`), which reads again; the next read that succeeds clears it. |
| HS-AS-06 | **Save score** (primary, large, full width, pinned at the bottom, `addScore.save`) is enabled with a score in the hole count's range (DM-OS-02) and a course. A score out of range shows "Enter a score from 40 to 200." (or 20 to 100) under the field. Saving goes back to Handicap. |
| HS-AS-07 | A failed save keeps the values and shows "Your score couldn't be saved." with **Try again** (`addScore.error`, `addScore.retry`); a future day (only possible through a clock change) says "The date can't be in the future." |
| HS-AS-08 | `AddOutsideScoreViewModel` (injected repositories and clock) validates through `OutsideScoreRules`. |

## 4. Add course
| ID | Requirement |
|----|-------------|
| HS-AC-01 | Back circle ("Back to add score", `addCourse.back`) and the title "Add course". |
| HS-AC-02 | **COURSE NAME** (placeholder "Course name", `addCourse.name`), then **RATING** (decimal pad, placeholder 71.2, a dot or a comma, one decimal, `addCourse.rating`) and **SLOPE** (number pad, placeholder 113, `addCourse.slope`) side by side. |
| HS-AC-03 | **Save course** (`addCourse.save`) is enabled with a name and a valid rating (50.0…85.0) and slope (55…155) (DM-OC-02…05). Invalid values show "Enter a rating from 50.0 to 85.0." / "Enter a slope from 55 to 155." under their field. Saving goes back to Add score, which selects the course. |
| HS-AC-04 | A name another course has, ignoring case and spaces (DM-OC-03), shows "A course with this name already exists." under the name (`addCourse.name.error`) and stays; editing the name clears it. A failed save shows "The course couldn't be saved." with **Try again**. |
| HS-AC-05 | `AddOutsideCourseViewModel` (injected `OutsideScoreRepository`). |

## 5. Testing
| ID | Test |
|----|------|
| HS-TS-01 | Unit (`HandicapScreenTests`): the explanation for every wording of the WHS table, too few rounds (plural variants) and a starting index with too few rounds (plural variants). |
| HS-TS-02 | Unit: the Handicap view model's rows, title, empty state, delete (outside only), a failed delete, a delete that finds nothing and a missing player. |
| HS-TS-03 | Unit: Add score's defaults, validation per hole count, no courses, save, a new course selected, failures keeping the values, a failed course read with Try again. |
| HS-TS-04 | Unit: Add course's parsing (dot and comma), validation, duplicate name and failed save. |
| HS-TS-05 | UI (`HandicapScreenUITests`, seed `outsideScores`): the Player card row opens Handicap with the same index; Add score › Add course › Save course › Save score lists the new score; swipe to delete an outside score; a Maynard row opens Round detail; a duplicate course name stays on Add course. |
