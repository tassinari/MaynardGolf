//
//  ScorecardTable.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The scorecard grid (SC-BH-04), reused by Round detail: holes as rows with players across in portrait
/// (08-scorecard §3), holes as columns with players down in landscape, like a paper card (§4). Read-only:
/// cells are static text with no tap or edit (SC-BH-07).
struct ScorecardTable: View {
    enum Layout { case portrait, landscape }

    let card: ScorecardModel
    let layout: Layout
    /// A player's avatar photo.
    var photo: (ScorecardModel.Column) -> UIImage? = { _ in nil }
    /// Round detail's portrait card (RD-SC-01, 02): a Tee Green header with first names only, 38 pt hole
    /// rows, 40 pt totals and 28 pt marks.
    var compact = false

    var body: some View {
        switch layout {
        case .portrait: portrait
        case .landscape: landscape
        }
    }

    // MARK: Portrait (§3)

    private var portrait: some View {
        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
            Section {
                ForEach(Array(card.rows.enumerated()), id: \.element.id) { index, row in
                    portraitRow(row, stripe: index.isMultiple(of: 2))
                }
            } header: {
                if compact { compactHeader } else { fullHeader }
            }
        }
        .overlay { portraitDividers }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scorecard.table")
    }

    /// Names only, on Tee Green (RD-SC-01).
    private var compactHeader: some View {
        HStack(spacing: 0) {
            Group {
                Text("Hole", comment: "Scorecard column title, shown in caps.").frame(width: 40)
                Text("Par", comment: "Scorecard column title, shown in caps.").frame(width: 34)
            }
            .dsFont(.labelSmall)
            .foregroundStyle(Color.ds.textSecondary)
            ForEach(0..<ScorecardModel.playerSlotCount, id: \.self) { position in
                if let column = card.playerSlots[position] {
                    Text(verbatim: column.firstName).dsFont(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.ds.textPrimary).lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("scorecard.player.\(column.playerID)")
                } else { emptySlot }
            }
        }
        .frame(height: 34)
        .background(Color.ds.teeGreen50)
    }

    /// The live Scorecard's pinned header: avatar, name and running to-par (SC-PT-02).
    private var fullHeader: some View {
        HStack(spacing: 0) {
            Group {
                Text("Hole", comment: "Scorecard column title, shown in caps.").frame(width: 40)
                Text("Par", comment: "Scorecard column title, shown in caps.").frame(width: 34)
            }
            .dsFont(.labelSmall)
            .foregroundStyle(Color.ds.textSecondary)
            ForEach(0..<ScorecardModel.playerSlotCount, id: \.self) { position in
                if let column = card.playerSlots[position] {
                    VStack(spacing: 2) {
                        PlayerAvatar(name: column.firstName, color: column.color.palette, photo: photo(column), size: .xs)
                        Text(verbatim: column.firstName).dsFont(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color.ds.textPrimary).lineLimit(1)
                        ToParText(value: column.toPar, style: .caption)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("scorecard.player.\(column.playerID)")
                } else { emptySlot }
            }
        }
        .padding(.vertical, DSSpacing.s)
        .background(Color.ds.surfaceCard)
    }

    @ViewBuilder private func portraitRow(_ row: ScorecardModel.Row, stripe: Bool) -> some View {
        switch row {
        case .hole(let number, let par, let scores, let isCurrent):
            HStack(spacing: 0) {
                Text(verbatim: "\(number)").dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary).frame(width: 40)
                Text(verbatim: "\(par)").dsFont(.caption).foregroundStyle(Color.ds.textSecondary).frame(width: 34)
                ForEach(0..<ScorecardModel.playerSlotCount, id: \.self) { position in
                    if let column = card.playerSlots[position] {
                        scoreCell(column: column, hole: number, par: par, score: scores[position], size: compact ? 28 : 30)
                            .frame(maxWidth: .infinity)
                    } else { emptySlot }
                }
            }
            .frame(minHeight: compact ? 38 : 40)
            .background(isCurrent ? Color.ds.currentHoleHighlight : (stripe ? Color.ds.surfaceCard : Color.ds.tableStripe))
            .overlay(alignment: .top) { DSDivider() }
        case .total(let segment, let par, let sums):
            HStack(spacing: 0) {
                Text(verbatim: Self.title(segment)).dsFont(.labelSmall).foregroundStyle(Color.ds.textOnTotals).frame(width: 40)
                Text(verbatim: "\(par)").dsFont(.caption).foregroundStyle(Color.ds.textOnTotals).frame(width: 34)
                ForEach(0..<ScorecardModel.playerSlotCount, id: \.self) { position in
                    if let column = card.playerSlots[position] {
                        totalCell(column: column, segment: segment, sum: sums[position]).frame(maxWidth: .infinity)
                    } else { emptySlot }
                }
            }
            .frame(minHeight: compact ? 40 : 42)
            .background(Color.ds.surfaceTotals)
        }
    }

    /// Blank display position: no avatar, dot, dash or fabricated player/score (#204).
    private var emptySlot: some View {
        Color.clear.frame(maxWidth: .infinity).accessibilityHidden(true)
    }

    /// One continuous semantic hairline at each player boundary, including empty columns. This overlay
    /// measures the actual table, so the four slots stay aligned in both live and compact cards (#204).
    private var portraitDividers: some View {
        GeometryReader { proxy in
            ForEach(1..<ScorecardModel.playerSlotCount, id: \.self) { boundary in
                Rectangle().fill(Color.ds.divider)
                    .frame(width: 1, height: proxy.size.height)
                    .position(x: 74 + max(proxy.size.width - 74, 0) * CGFloat(boundary) / CGFloat(ScorecardModel.playerSlotCount),
                              y: proxy.size.height / 2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Landscape (§4)

    /// Fills the width on a phone; scrolls sideways only where 18 holes don't fit (SC-LS-05).
    private var landscape: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                landscapeGrid.frame(minWidth: proxy.size.width)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
    }

    private var landscapeGrid: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                landscapeLabel(Text("Hole", comment: "Scorecard column title, shown in caps."))
                ForEach(card.rows) { row in
                    landscapeHeader(row) { number in
                        Text(verbatim: "\(number)").dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
                    }
                }
            }
            .frame(height: 34)
            .background(Color.ds.teeGreen50)
            GridRow {
                landscapeLabel(Text("Par", comment: "Scorecard column title, shown in caps."))
                ForEach(card.rows) { row in
                    Text(verbatim: "\(Self.par(row))").dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Self.isTotal(row) ? Color.ds.surfaceTotals : Color.clear)
                }
            }
            .frame(height: 30)
            .background(Color.ds.tableStripe)
            ForEach(Array(card.columns.enumerated()), id: \.element.id) { playerIndex, column in
                GridRow {
                    HStack(spacing: DSSpacing.xs) {
                        PlayerAvatar(name: column.firstName, color: column.color.palette, photo: photo(column), size: .xxs)
                        Text(verbatim: column.firstName).dsFont(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color.ds.textPrimary).lineLimit(1)
                    }
                    .frame(width: 112, alignment: .leading)
                    .padding(.leading, DSSpacing.s)
                    .accessibilityElement(children: .combine)
                    ForEach(card.rows) { row in
                        landscapeCell(row, column: column, playerIndex: playerIndex)
                    }
                }
                .frame(height: 46)
                .overlay(alignment: .top) { DSDivider() }
            }
        }
    }

    private func landscapeLabel(_ text: Text) -> some View {
        text.dsFont(.labelSmall).foregroundStyle(Color.ds.textSecondary)
            .frame(width: 112, alignment: .leading).padding(.leading, DSSpacing.s)
    }

    @ViewBuilder private func landscapeHeader(_ row: ScorecardModel.Row, hole: (Int) -> some View) -> some View {
        switch row {
        case .hole(let number, _, _, let isCurrent):
            hole(number).frame(minWidth: 30, maxWidth: .infinity, maxHeight: .infinity)
                .background(isCurrent ? Color.ds.currentHoleHighlight : Color.clear)
        case .total(let segment, _, _):
            Text(verbatim: Self.title(segment)).dsFont(.labelSmall).foregroundStyle(Color.ds.textOnTotals)
                .frame(minWidth: segment == .tot ? 46 : 42, maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ds.bunker300)
        }
    }

    @ViewBuilder private func landscapeCell(_ row: ScorecardModel.Row, column: ScorecardModel.Column, playerIndex: Int) -> some View {
        switch row {
        case .hole(let number, let par, let scores, let isCurrent):
            scoreCell(column: column, hole: number, par: par, score: scores[playerIndex], size: 26)
                .frame(minWidth: 30, maxWidth: .infinity, maxHeight: .infinity)
                .background(isCurrent ? Color.ds.currentHoleHighlight : Color.clear)
        case .total(let segment, _, let sums):
            totalCell(column: column, segment: segment, sum: sums[playerIndex])
                .frame(minWidth: segment == .tot ? 46 : 42, maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ds.surfaceTotals)
        }
    }

    // MARK: Cells

    private func scoreCell(column: ScorecardModel.Column, hole: Int, par: Int, score: Int?, size: CGFloat) -> some View {
        ScoreMark(score: score, par: par, size: size)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: ScorecardViewModel.cellLabel(player: column.firstName, hole: hole, score: score, par: par)))
            .accessibilityIdentifier("scorecard.cell.\(hole).\(column.playerID)")
    }

    /// A sum, or "–" for a segment with no scores yet (SC-PT-06).
    private func totalCell(column: ScorecardModel.Column, segment: ScorecardModel.Segment, sum: Int?) -> some View {
        Text(verbatim: sum.map(String.init) ?? "–").dsFont(.bodyEmphasized).dsNumeric().foregroundStyle(Color.ds.textOnTotals)
            .accessibilityIdentifier("scorecard.total.\(segment.rawValue).\(column.playerID)")
    }

    /// "Out", "In", "Tot" (shown in caps).
    static func title(_ segment: ScorecardModel.Segment) -> String {
        switch segment {
        case .out: String(localized: "Out", comment: "Scorecard: the front nine's total, shown in caps.")
        case .in: String(localized: "In", comment: "Scorecard: the back nine's total, shown in caps.")
        case .tot: String(localized: "Tot", comment: "Scorecard: the round's total, shown in caps.")
        }
    }

    private static func par(_ row: ScorecardModel.Row) -> Int {
        switch row {
        case .hole(_, let par, _, _), .total(_, let par, _): par
        }
    }

    private static func isTotal(_ row: ScorecardModel.Row) -> Bool {
        if case .total = row { return true }
        return false
    }
}

#if DEBUG
/// Fixed snapshot fixtures for the portrait table's occupied and empty positions (#204, TS-VS-05).
@MainActor
private func portraitTablePreview(players count: Int, compact: Bool = false, holes: HoleCount = .nine) -> some View {
    do {
        let container = try PersistenceController.makeContainer(.preview(.freshInstall))
        let context = container.mainContext
        let names = ["Mark", "Scottie", "Tiger", "Phil"]
        let players = (0..<max(count, 1)).map { ModelFixtures.player(names[$0], color: PlayerColor.allCases[$0], in: context) }
        let round = try ModelFixtures.round(players: players, holeCount: holes, weather: ModelFixtures.weather(.sunny),
                                           thru: 5, in: context)
        let model = ScorecardModel(round: RoundSnapshot(round), players: count == 0 ? [] : players.map(PlayerSnapshot.init),
                                   course: try BundleCourseProvider().course(id: AppDependencies.courseID))
        return ScrollView { ScorecardTable(card: model, layout: .portrait, compact: compact) }
            .background(Color.ds.background)
    } catch { preconditionFailure("Scorecard preview failed: \(error)") }
}
#Preview("One player, three blank columns") { portraitTablePreview(players: 1) }
#Preview("Two players, two blank columns") { portraitTablePreview(players: 2) }
#Preview("Three players, one blank column") { portraitTablePreview(players: 3) }
#Preview("Four players") { portraitTablePreview(players: 4) }
#Preview("No resolved players") { portraitTablePreview(players: 0) }
#Preview("Round detail, one player") { portraitTablePreview(players: 1, compact: true) }
#Preview("Round detail, two players") { portraitTablePreview(players: 2, compact: true) }
#Preview("Round detail, three players") { portraitTablePreview(players: 3, compact: true) }
#Preview("Round detail, four players, 18 holes") { portraitTablePreview(players: 4, compact: true, holes: .eighteen) }
#Preview("One player, Dark") { portraitTablePreview(players: 1).preferredColorScheme(.dark) }
#Preview("Round detail, Dark") { portraitTablePreview(players: 1, compact: true).preferredColorScheme(.dark) }
#endif
