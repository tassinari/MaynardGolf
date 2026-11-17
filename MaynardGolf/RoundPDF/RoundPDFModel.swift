//
//  RoundPDFModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI

/// Everything the round PDF's page shows (15-round-pdf, RP-AR-01): the header strings, the layout, the
/// columns and the rows with their cells, already formatted. A pure value built by `RoundPDFModelBuilder`
/// from value snapshots, so the page view only draws it and every rule is unit-tested without rendering.
struct RoundPDFModel: Equatable, Sendable {
    /// 18 holes (OUT / IN / TOT / +/−) or 9 holes (TOT / +/−, larger type) (RP-TB-01, RP-TB-02).
    enum Layout: Equatable, Sendable {
        case eighteen, nine
    }

    /// The header's four lines (RP-HD-01…04), final text in the case the page prints.
    struct Header: Equatable, Sendable {
        /// "MAYNARD GOLF CLUB · ROUND SCORECARD", or "· 9-HOLE SCORECARD" (RP-HD-01).
        let eyebrow: String
        /// "Sat, Nov 8, 2026" (RP-HD-02).
        let date: String
        /// "BLUE TEES · PAR 70 · 6,026 YDS"; "FRONT 9 · BLUE TEES · PAR 35 · 3,013 YDS" for 9 holes (RP-HD-03).
        let teeLine: String
        /// "TEE TIME 8:40 AM · 4H 12M · SUNNY 62°", without the parts the round doesn't have (RP-HD-04).
        let metaLine: String
    }

    /// A data column, after the label column (RP-TB-01, RP-TB-02).
    enum Column: Equatable, Sendable, Identifiable {
        /// A hole, by its number in the round (1…18).
        case hole(Int)
        case out, `in`, tot, toPar

        /// OUT / IN / TOT / +/− cells are shaded as totals (RP-TB-03, 05, 09).
        var isTotal: Bool {
            if case .hole = self { return false }
            return true
        }

        var id: String {
            switch self {
            case .hole(let number): "hole.\(number)"
            case .out: "out"
            case .in: "in"
            case .tot: "tot"
            case .toPar: "toPar"
            }
        }
    }

    /// One cell's content.
    enum Cell: Equatable, Sendable {
        /// Nothing: an unscored hole, the YARDS / PAR rows' +/− or a blank row (RP-TB-08, RP-TB-10).
        case empty
        /// A number or label, already formatted ("3,013", "OUT", "E", "−2").
        case text(String)
        /// A hole score and how it's marked (RP-TB-07).
        case score(Int, ScoreFormatter.MarkStyle)
    }

    /// Which row a row is, which decides its colors, type and height (RP-TB-03…06, RP-TB-11).
    enum RowKind: Equatable, Sendable {
        case hole, yards, par, player, blank
    }

    /// One table row: a label and one cell per column.
    struct Row: Equatable, Sendable, Identifiable {
        /// "hole", "yards", "par", "player.{entry id}" or "blank.{n}".
        let id: String
        let kind: RowKind
        /// "HOLE", "YARDS", "PAR", a player's first name, or "" for a blank row (RP-TB-06).
        let label: String
        let cells: [Cell]
    }

    let layout: Layout
    let header: Header
    let columns: [Column]
    /// HOLE, YARDS, PAR, then the players in round order, padded to 4 with blank rows (RP-TB-10).
    let rows: [Row]
    /// "Round · Maynard Golf Club · Nov 8": the file name without ".pdf" and the PDF's title (RP-EX-04, 05).
    let title: String

    /// The table always has room for this many players (RP-TB-10).
    static let playerRows = 4
}

/// Builds a `RoundPDFModel` from a round, its players and the course (RP-AR-01). Totals and to-par come
/// from `ScorecardModel`, so the PDF adds up exactly like the on-screen scorecard (RP-TB-08, RP-AR-04).
enum RoundPDFModelBuilder {
    /// `locale` and `calendar` are injected so the strings are tested in a fixed region and time zone.
    static func build(round: RoundSnapshot, players: [PlayerSnapshot], course: Course,
                      locale: Locale = .current, calendar: Calendar = .current) -> RoundPDFModel {
        let layout: RoundPDFModel.Layout = round.holeCount == .eighteen ? .eighteen : .nine
        let holes = RoundHoleBuilder.holes(course: course, holeCount: round.holeCount)
        let scorecard = ScorecardModel(round: round, players: players, course: course)
        let columns = columns(holeCount: holes.count)
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let title = String(localized: "Round · \(course.name) · \(round.startedAt.formatted(style.month(.abbreviated).day()))",
                           comment: "Round PDF: the file name (without .pdf) and the PDF's title, e.g. 'Round · Maynard Golf Club · Nov 8'.")
        return RoundPDFModel(
            layout: layout,
            header: header(round: round, course: course, holes: holes, layout: layout, style: style, locale: locale),
            columns: columns,
            rows: tableRows(holes: holes, tee: round.tee, scorecard: scorecard, columns: columns, locale: locale),
            title: title)
    }

    // MARK: Header

    private static func header(round: RoundSnapshot, course: Course, holes: [RoundHole], layout: RoundPDFModel.Layout,
                               style: Date.FormatStyle, locale: Locale) -> RoundPDFModel.Header {
        let kind = layout == .eighteen
            ? String(localized: "Round scorecard", comment: "Round PDF: the eyebrow's second part for an 18-hole round. Shown in caps.")
            : String(localized: "9-hole scorecard", comment: "Round PDF: the eyebrow's second part for a 9-hole round. Shown in caps.")
        let teeName = course.tee(round.tee)?.localizedName ?? round.tee.localizedName
        let par = holes.reduce(0) { $0 + $1.par }
        let yards = holes.reduce(0) { $0 + $1.source.yards(from: round.tee) }
        var tee = [
            String(localized: "\(teeName) tees", comment: "Round complete: the tee played, e.g. 'Blue tees'. Shown in caps."),
            String(localized: "Par \(par)", comment: "Round detail: the round's par, e.g. 'Par 72'. Shown in caps."),
            String(localized: "\(yards.formatted(.number.grouping(.automatic).locale(locale))) yds",
                   comment: "Tee card: total yardage for the round, e.g. '3,013 yds'."),
        ]
        if layout == .nine {
            tee.insert(String(localized: "Front 9", comment: "Round PDF: a 9-hole round's nine, before the tees. Shown in caps."), at: 0)
        }
        let time = round.startedAt.formatted(style.hour().minute())
        var meta = [String(localized: "Tee time \(time)", comment: "Round detail: when the round started, e.g. 'Tee time 8:40 AM'.")]
        if let duration = RoundDetailContent.duration(of: round, locale: locale) { meta.append(duration) }
        if let weather = round.weather {
            meta.append(String(localized: "\(weather.condition.icon.title) \(weather.temperatureF)°",
                               comment: "Round PDF: the weather at tee off, e.g. 'Sunny 62°'. Shown in caps."))
        }
        return RoundPDFModel.Header(
            eyebrow: [course.name, kind].joined(separator: " · ").uppercased(with: locale),
            date: round.startedAt.formatted(style.weekday(.abbreviated).month(.abbreviated).day().year()),
            teeLine: tee.joined(separator: " · ").uppercased(with: locale),
            metaLine: meta.joined(separator: " · ").uppercased(with: locale))
    }

    // MARK: Table

    /// Holes 1–9, OUT, 10–18, IN, TOT, +/− for 18 holes; holes 1–9, TOT, +/− for 9 (RP-TB-01, RP-TB-02).
    static func columns(holeCount: Int) -> [RoundPDFModel.Column] {
        let holes = (1...max(holeCount, 1)).map(RoundPDFModel.Column.hole)
        guard holeCount > 9 else { return holes + [.tot, .toPar] }
        return holes.prefix(9) + [.out] + holes.dropFirst(9) + [.in, .tot, .toPar]
    }

    private static func tableRows(holes: [RoundHole], tee: Tee, scorecard: ScorecardModel, columns: [RoundPDFModel.Column],
                                  locale: Locale) -> [RoundPDFModel.Row] {
        let number = IntegerFormatStyle<Int>.number.grouping(.automatic).locale(locale)
        /// The value of each column for a row of per-hole numbers: the holes, then OUT / IN / TOT sums.
        func line(_ values: [Int?], toPar: RoundPDFModel.Cell, hole: (Int) -> RoundPDFModel.Cell) -> [RoundPDFModel.Cell] {
            let totals = ScoreFormatter.totals(values)
            return columns.map { column in
                switch column {
                case .hole(let n): hole(n - 1) // the columns are built from the same holes, so n is always in range
                case .out: text(totals.out)
                case .in: text(totals.in)
                case .tot: text(totals.total)
                case .toPar: toPar
                }
            }
        }
        func text(_ value: Int?) -> RoundPDFModel.Cell { value.map { .text($0.formatted(number)) } ?? .empty }
        let pars = holes.map(\.par)
        let yards = holes.map { $0.source.yards(from: tee) }

        let headerCells: [RoundPDFModel.Cell] = columns.map { column in
            switch column {
            case .hole(let n): .text("\(n)")
            case .out: .text(caps(String(localized: "Out", comment: "Scorecard: the front nine's total, shown in caps."), locale))
            case .in: .text(caps(String(localized: "In", comment: "Scorecard: the back nine's total, shown in caps."), locale))
            case .tot: .text(caps(String(localized: "Tot", comment: "Scorecard: the round's total, shown in caps."), locale))
            case .toPar: .text(String(localized: "+/−", comment: "Round PDF: the to-par column's title."))
            }
        }
        var rows: [RoundPDFModel.Row] = [
            .init(id: "hole", kind: .hole,
                  label: caps(String(localized: "Hole", comment: "Scorecard column title, shown in caps."), locale), cells: headerCells),
            .init(id: "yards", kind: .yards,
                  label: caps(String(localized: "Yards", comment: "Round PDF: the yardage row's title. Shown in caps."), locale),
                  cells: line(yards, toPar: .empty) { text(yards[$0]) }),
            .init(id: "par", kind: .par,
                  label: caps(String(localized: "Par", comment: "Scorecard column title, shown in caps."), locale),
                  cells: line(pars, toPar: .empty) { text(pars[$0]) }),
        ]
        for player in scorecard.columns {
            let toPar: RoundPDFModel.Cell = player.totals.total == nil ? .empty : .text(ScoreFormatter.toPar(player.toPar))
            let cells = line(player.scores, toPar: toPar) { index in
                guard let score = player.scores[index] else { return .empty }
                return .score(score, ScoreFormatter.markStyle(score: score, par: pars[index]))
            }
            rows.append(.init(id: "player.\(player.id)", kind: .player, label: player.firstName, cells: cells))
        }
        let blanks = max(RoundPDFModel.playerRows - scorecard.columns.count, 0)
        rows += (0..<blanks).map { .init(id: "blank.\($0)", kind: .blank, label: "", cells: columns.map { _ in .empty }) }
        return rows
    }

    private static func caps(_ text: String, _ locale: Locale) -> String { text.uppercased(with: locale) }
}
