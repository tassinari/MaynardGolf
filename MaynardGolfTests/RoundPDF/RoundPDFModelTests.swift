//
//  RoundPDFModelTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import SwiftData
import Testing
@testable import MaynardGolf

/// 15-round-pdf: the PDF's value model and its builder (RP-AR-01, RP-TS-01, RP-TS-02; #110).
@MainActor
struct RoundPDFModelTests {
    private typealias F = ModelFixtures
    private let context: ModelContext
    private let course: Course
    private let utc: Calendar
    private let en = Locale(identifier: "en_US")
    /// Saturday 8 November 2025, 8:40 UTC.
    private let saturday: Date

    init() throws {
        context = try makeInMemoryContext()
        course = try BundleCourseProvider().course(id: "MaynardGC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        utc = calendar
        saturday = calendar.date(from: DateComponents(year: 2025, month: 11, day: 8, hour: 8, minute: 40))!
    }

    private func model(_ round: Round) -> RoundPDFModel {
        RoundPDFModelBuilder.build(round: RoundSnapshot(round), players: round.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init),
                                   course: course, locale: en, calendar: utc)
    }

    private func players(_ names: [String]) -> [Player] { names.map { F.player($0, in: context) } }

    private func row(_ model: RoundPDFModel, _ id: String) throws -> RoundPDFModel.Row {
        try #require(model.rows.first { $0.id == id })
    }

    /// The cell under a column in a row.
    private func cell(_ model: RoundPDFModel, _ row: RoundPDFModel.Row, _ column: RoundPDFModel.Column) throws -> RoundPDFModel.Cell {
        try row.cells[#require(model.columns.firstIndex(of: column))]
    }

    // MARK: Layout and columns

    /// RP-TB-01, RP-TB-10: 18 holes, 4 players → holes 1–9, OUT, 10–18, IN, TOT, +/− and no blank rows.
    @Test func eighteenHolesFourPlayers() throws {
        let round = try F.completedRound(players: players(["Mark", "Scottie", "Tiger", "Phil"]), holeCount: .eighteen,
                                         tee: .blue, startedAt: saturday, in: context)
        let pdf = model(round)
        #expect(pdf.layout == .eighteen)
        #expect(pdf.columns == (1...9).map(RoundPDFModel.Column.hole) + [.out] + (10...18).map(RoundPDFModel.Column.hole) + [.in, .tot, .toPar])
        #expect(pdf.rows.map(\.kind) == [.hole, .yards, .par, .player, .player, .player, .player])
        #expect(pdf.rows.dropFirst(3).map(\.label) == ["Mark", "Scottie", "Tiger", "Phil"])
        #expect(pdf.rows.allSatisfy { $0.cells.count == 22 })
    }

    /// RP-TB-02, RP-TB-10: 9 holes, 2 players → holes 1–9, TOT, +/− and 2 blank rows with nothing in them.
    @Test func nineHolesTwoPlayers() throws {
        let round = try F.completedRound(players: players(["Mark", "Kevin"]), startedAt: saturday, in: context)
        let pdf = model(round)
        #expect(pdf.layout == .nine)
        #expect(pdf.columns == (1...9).map(RoundPDFModel.Column.hole) + [.tot, .toPar])
        #expect(pdf.rows.map(\.kind) == [.hole, .yards, .par, .player, .player, .blank, .blank])
        let blanks = pdf.rows.filter { $0.kind == .blank }
        #expect(blanks.map(\.id) == ["blank.0", "blank.1"])
        #expect(blanks.allSatisfy { $0.label.isEmpty && $0.cells == Array(repeating: .empty, count: 11) })
    }

    /// RP-TB-10: always 4 player rows, from 1 player to 4.
    @Test(arguments: 1...4)
    func paddedToFourRows(count: Int) throws {
        let round = try F.completedRound(players: players(Array(["A", "B", "C", "D"].prefix(count))), startedAt: saturday, in: context)
        let pdf = model(round)
        #expect(pdf.rows.count(where: { $0.kind == .player }) == count)
        #expect(pdf.rows.count(where: { $0.kind == .player || $0.kind == .blank }) == RoundPDFModel.playerRows)
    }

    /// Column identities and which columns are totals (RP-TB-03).
    @Test func columnIdentity() {
        #expect(RoundPDFModel.Column.hole(3).id == "hole.3")
        #expect([RoundPDFModel.Column.out, .in, .tot, .toPar].map(\.id) == ["out", "in", "tot", "toPar"])
        #expect(!RoundPDFModel.Column.hole(1).isTotal)
        let totals: [RoundPDFModel.Column] = [.out, .in, .tot, .toPar]
        #expect(totals.allSatisfy { $0.isTotal })
    }

    // MARK: Header

    /// RP-HD-01…04 for both layouts: the eyebrow, the date with its year, tees · par · yards and
    /// tee time · duration · weather, in caps.
    @Test(arguments: [
        (HoleCount.eighteen, "MAYNARD GOLF CLUB · ROUND SCORECARD", "BLUE TEES · PAR 70 · 6,026 YDS", "4H 30M"),
        (.nine, "MAYNARD GOLF CLUB · 9-HOLE SCORECARD", "FRONT 9 · BLUE TEES · PAR 35 · 3,013 YDS", "2H 15M"),
    ])
    func header(holeCount: HoleCount, eyebrow: String, teeLine: String, duration: String) throws {
        let round = try F.completedRound(players: players(["Mark"]), holeCount: holeCount, tee: .blue, startedAt: saturday,
                                         weather: F.weather(.partlyCloudy, temperatureF: 62), in: context)
        let header = model(round).header
        #expect(header.eyebrow == eyebrow)
        #expect(header.date == "Sat, Nov 8, 2025")
        #expect(header.teeLine == teeLine)
        #expect(header.metaLine == "TEE TIME 8:40\u{202F}AM · \(duration) · PARTLY CLOUDY 62°")
    }

    /// RP-HD-04: no duration for a round without a finish, and no weather for a round without it.
    @Test func headerLeavesOutWhatTheRoundLacks() throws {
        let round = try F.inProgressRound(players: players(["Mark"]), thru: 3, startedAt: saturday, in: context)
        #expect(model(round).header.metaLine == "TEE TIME 8:40\u{202F}AM")
    }

    /// RP-HD-03: course data without the round's tee still names it, from the tee's own name (HOME-RR-03).
    @Test func teeMissingFromCourseData() throws {
        let round = try F.completedRound(players: players(["Mark"]), tee: .red, startedAt: saturday, in: context)
        let noRed = Course(id: course.id, name: course.name, coordinate: course.coordinate, tees: course.tees.filter { $0.id != .red },
                           holes: course.holes, localRules: course.localRules)
        let pdf = RoundPDFModelBuilder.build(round: RoundSnapshot(round), players: round.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init),
                                             course: noRed, locale: en, calendar: utc)
        #expect(pdf.header.teeLine.hasPrefix("FRONT 9 · RED TEES"))
    }

    /// RP-EX-04, RP-EX-05: the title the file and the PDF are named after.
    @Test func title() throws {
        let round = try F.completedRound(players: players(["Mark"]), startedAt: saturday, in: context)
        #expect(model(round).title == "Round · Maynard Golf Club · Nov 8")
    }

    // MARK: Rows

    /// RP-TB-03…05: HOLE titles, then yards and par per hole with OUT / IN / TOT sums (thousands
    /// separators) and an empty +/−, for every tee.
    @Test(arguments: [(Tee.blue, 3_013), (.white, 2_853), (.yellow, 2_718), (.red, 2_601)])
    func yardsAndParPerTee(tee: Tee, nineYards: Int) throws {
        let round = try F.completedRound(players: players(["Mark"]), holeCount: .eighteen, tee: tee, startedAt: saturday, in: context)
        let pdf = model(round)
        let nine = nineYards.formatted(.number.locale(en))
        let total = (nineYards * 2).formatted(.number.locale(en))

        let holes = try row(pdf, "hole")
        #expect(holes.label == "HOLE")
        #expect(try cell(pdf, holes, .hole(10)) == .text("10"))
        #expect(try [.out, .in, .tot, .toPar].map { try cell(pdf, holes, $0) } == [.text("OUT"), .text("IN"), .text("TOT"), .text("+/−")])

        let yards = try row(pdf, "yards")
        #expect(yards.label == "YARDS")
        #expect(try cell(pdf, yards, .hole(1)) == .text("\(course.holes[0].yards(from: tee))"))
        #expect(try cell(pdf, yards, .hole(10)) == (try cell(pdf, yards, .hole(1))))
        #expect(try [.out, .in, .tot, .toPar].map { try cell(pdf, yards, $0) } == [.text(nine), .text(nine), .text(total), .empty])

        let par = try row(pdf, "par")
        #expect(par.label == "PAR")
        #expect(try cell(pdf, par, .hole(2)) == .text("5"))
        #expect(try [.out, .in, .tot, .toPar].map { try cell(pdf, par, $0) } == [.text("35"), .text("35"), .text("70"), .empty])
    }

    /// RP-TB-06…09: a player's row has a mark per hole, OUT / IN / TOT sums and +/− against par.
    @Test func playerRow() throws {
        let scores = [[4, 6, 3, 4, 4, 3, 4, 4, 4, 4, 5, 2, 4, 4, 3, 4, 4, 4]]
        let round = try F.round(players: players(["Mark"]), holeCount: .eighteen, startedAt: saturday, scores: scores, in: context)
        let pdf = model(round)
        let mark = try row(pdf, "player.\(round.sortedEntries[0].id)")
        #expect(mark.kind == .player)
        #expect(try cell(pdf, mark, .hole(1)) == .score(4, .plain))
        #expect(try cell(pdf, mark, .hole(2)) == .score(6, .square))
        #expect(try cell(pdf, mark, .hole(12)) == .score(2, .circle))
        #expect(try [.out, .in, .tot, .toPar].map { try cell(pdf, mark, $0) } == [.text("36"), .text("34"), .text("70"), .text("E")])
    }

    /// RP-TB-09: +/− reads "E", "+n" or "−n" with a real minus sign.
    @Test(arguments: [(-2, "\u{2212}2"), (0, "E"), (3, "+3")])
    func toPar(difference: Int, text: String) throws {
        var scores = F.pars
        scores[0] += difference
        let round = try F.round(players: players(["Mark"]), startedAt: saturday, scores: [scores], in: context)
        let pdf = model(round)
        #expect(try cell(pdf, row(pdf, "player.\(round.sortedEntries[0].id)"), .toPar) == .text(text))
    }

    /// RP-TB-08: unscored holes are empty and left out of the totals; +/− counts only the scored holes.
    @Test func unscoredHoles() throws {
        let scores = [[5, 6, 3, 4, 4, 3, 4, 4, 4, 5, 5, 3, 4, 4, 3, 4, 4, 4]]
        let round = try F.round(players: players(["Mark"]), holeCount: .eighteen, startedAt: saturday, thru: 3, scores: scores, in: context)
        let pdf = model(round)
        let mark = try row(pdf, "player.\(round.sortedEntries[0].id)")
        #expect(try cell(pdf, mark, .hole(4)) == .empty)
        #expect(try cell(pdf, mark, .hole(18)) == .empty)
        #expect(try [.out, .in, .tot, .toPar].map { try cell(pdf, mark, $0) } == [.text("14"), .empty, .text("14"), .text("+2")])
    }

    /// RP-TB-08: a player with no scores at all has empty totals and +/−, not 0 and "E".
    @Test func playerWithNoScores() throws {
        let round = try F.round(players: players(["Mark"]), startedAt: saturday, thru: 0, in: context)
        let pdf = model(round)
        let mark = try row(pdf, "player.\(round.sortedEntries[0].id)")
        #expect(mark.cells.allSatisfy { $0 == .empty })
    }

    /// RP-TS-02: the mark for every score from 3 under to 5 over par (DS-GF-01).
    @Test(arguments: [
        (-3, ScoreFormatter.MarkStyle.doubleCircle), (-2, .doubleCircle), (-1, .circle), (0, .plain),
        (1, .square), (2, .filledSquare), (3, .filledSquare), (4, .filledSquare), (5, .filledSquare),
    ])
    func markKind(difference: Int, style: ScoreFormatter.MarkStyle) throws {
        var scores = F.pars
        scores[1] += difference // hole 2 is a par 5, so 3 under is still a score of 2
        let round = try F.round(players: players(["Mark"]), startedAt: saturday, scores: [scores], in: context)
        let pdf = model(round)
        #expect(try cell(pdf, row(pdf, "player.\(round.sortedEntries[0].id)"), .hole(2)) == .score(5 + difference, style))
    }

    /// RP-TB-06: the label is the first name only, kept whole (the page truncates it), in round order.
    @Test func firstNameOnly() throws {
        let long = F.player("Bartholomew-Ångström", "Smith", in: context)
        let round = try F.completedRound(players: [long, F.player("Ann", "Lee", in: context)], startedAt: saturday, in: context)
        #expect(model(round).rows.filter { $0.kind == .player }.map(\.label) == ["Bartholomew-Ångström", "Ann"])
    }
}
