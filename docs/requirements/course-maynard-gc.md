# Course data — Maynard Golf Course

**Source:** official scorecard, https://www.maynardgolf.com/aboutus/scorecard/ (PDF / JPG, front and back). Maynard Golf Course, est. 1921, 50 Brown Street, Maynard, MA 01754.

Maynard is a **9-hole course**. The card is printed as 18 holes: the second nine (holes 10–18) replays holes 1–9 with the **same par and yardage** but **different handicaps**. This is the reference data for `MaynardGC.json` and the 9 / 18-hole option in New round (NR-HOL-*).

## 1. Hole data (as printed)

| Hole | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | Out |
|------|---|---|---|---|---|---|---|---|---|-----|
| **Blue** | 385 | 512 | 170 | 372 | 365 | 196 | 353 | 348 | 312 | 3013 |
| **White** | 375 | 487 | 148 | 345 | 355 | 165 | 342 | 338 | 298 | 2853 |
| **Yellow** | 365 | 435 | 143 | 335 | 353 | 157 | 280 | 342 | 308 | 2718 |
| **Red** | 355 | 425 | 143 | 295 | 353 | 141 | 279 | 331 | 279 | 2601 |
| **Par** | 4 | 5 | 3 | 4 | 4 | 3 | 4 | 4 | 4 | 35 |
| **Handicap (front)** | 2 | 10 | 12 | 6 | 4 | 18 | 14 | 8 | 16 | |

| Hole | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | In | Total |
|------|----|----|----|----|----|----|----|----|----|----|-------|
| Plays as hole | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | | |
| **Blue** | 385 | 512 | 170 | 372 | 365 | 196 | 353 | 348 | 312 | 3013 | 6026 |
| **White** | 375 | 487 | 148 | 345 | 355 | 165 | 342 | 338 | 298 | 2853 | 5706 |
| **Yellow** | 365 | 435 | 143 | 335 | 353 | 157 | 280 | 342 | 308 | 2718 | 5436 |
| **Red** | 355 | 425 | 143 | 295 | 353 | 141 | 279 | 331 | 279 | 2601 | 5202 |
| **Par** | 4 | 5 | 3 | 4 | 4 | 3 | 4 | 4 | 4 | 35 | 71 |
| **Handicap (back)** | 1 | 11 | 13 | 5 | 3 | 17 | 7 | 9 | 15 | | |

## 2. Tees — rating / slope (18 holes, as printed)

| Tee | Rating / Slope | 18-hole yards |
|-----|----------------|---------------|
| Blue | 68.2 / 123 | 6,026 |
| White | 68.2 / 123 | 5,706 |
| Yellow | 71.5 / 124 | 5,436 |
| Red | 71.5 / 124 | 5,202 |

The card prints Blue and White with the same rating / slope, and Yellow and Red with the same values (most likely women's ratings for the forward tees). Use them exactly as printed until the club confirms otherwise. For a 9-hole round, show the 9-hole rating as half of the 18-hole rating, with the same slope (*inferred*; USGA 9-hole ratings may differ).

**Tees are Blue, White, Yellow and Red.** This settles the design's sample "Black / Blue / White / Red". The app uses the course data, and there are no Black tees.

## 3. Handicap (stroke index) rules in the app

| ID | Requirement |
|----|-------------|
| CRS-HC-01 | **18-hole round:** holes 1–9 use the front handicaps (2, 10, 12, 6, 4, 18, 14, 8, 16) and holes 10–18 use the back handicaps (1, 11, 13, 5, 3, 17, 7, 9, 15), exactly as printed. |
| CRS-HC-02 | **9-hole round:** handicaps are the **rank of the front-nine values, 1–9**: hole 1 → 1, hole 2 → 5, hole 3 → 6, hole 4 → 3, hole 5 → 2, hole 6 → 9, hole 7 → 7, hole 8 → 4, hole 9 → 8. This matches the design's "Hole 1 · HCP 1". Calculate this from the front values; don't store it separately. |
| CRS-HC-03 | Course JSON stores `handicapFront` and `handicapBack` per hole (replacing `handicap`). The 9-hole rank is calculated (`RoundHoleBuilder`). |

## 4. Corrections needed in `MaynardGC.json` (v1 data vs. official card)

| Field | Current JSON | Official card |
|-------|--------------|---------------|
| Hole handicaps (`handicap`, holes 1–9) | 1, 7, 8, 3, 2, 9, 4, 5, 6 | Front 2, 10, 12, 6, 4, 18, 14, 8, 16 · Back 1, 11, 13, 5, 3, 17, 7, 9, 15 · 9-hole rank 1, 5, 6, 3, 2, 9, 7, 4, 8 |
| Hole 7 Yellow yards | 342 | **280** |
| Hole 7 Red yards | 331 | **279** |
| Course rating / slope | single 69.1 / 125 | per tee (see §2) |
| JSON validity | trailing comma after hole 9 (invalid JSON) | remove it |

Blue and White yardages and all pars already match the card.

## 5. Local rules printed on the card

These are the rules shown in the app (03-local-rules LR-RC-05, where they're split into 12 numbered items).

- USGA Rules govern play unless amended by local rules.
- Out of bounds: parking lot, off-club property defined by white stakes.
- Ball coming to rest in a bark mulch area may be lifted and dropped one club length, no nearer the hole, with no penalty.
- All service roads, cart paths, fairway drainage ditches and protective fences: free lift to the nearest point of relief, no nearer the hole.
- Ball coming to rest in the confines of a rock or rocks through the green may be moved one club length without penalty.
- Players not holding their places on the golf course must allow other groups to play through.
- Players on the 1st tee must alternate with players coming off the 9th green.
- Do not climb the face of bunkers. Rake bunkers and return the rake to inside the bunker. Keep all carts off aprons and greens. Repair ball marks on green. Replace divots. Please speed up play.
- Maynard Golf Course is a soft-spike facility.
