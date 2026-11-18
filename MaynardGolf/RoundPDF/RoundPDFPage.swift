//
//  RoundPDFPage.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The round PDF's one page (15-round-pdf §2–4): the header and the scorecard table of a `RoundPDFModel`,
/// laid out for a standard golf scorecard, 11 × 4.25 in (RP-PG-02). Print style only (RP-AR-04): fixed
/// light primitives and fixed point sizes, so the device's appearance and Dynamic Type never change it
/// (RP-PG-03). It doesn't reuse the on-screen `ScorecardTable`, whose layout is different.
struct RoundPDFPage: View {
    let model: RoundPDFModel

    /// 11 × 4.25 in, landscape, in PDF points (RP-PG-02).
    static let size = CGSize(width: 792, height: 306)
    /// The margin around the header and table (RP-PG-02).
    static let margin: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundPDFHeader(header: model.header)
            RoundPDFTable(model: model)
        }
        .padding(Self.margin)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
        .background(Color.ds.white)
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
    }
}

/// The header (RP-HD-01…05): eyebrow and date on the left, tees and tee time on the right, a 2 pt rule under.
private struct RoundPDFHeader: View {
    let header: RoundPDFModel.Header

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: header.eyebrow)
                    .font(.system(size: 11, weight: .bold)).tracking(11 * 0.16)
                    .foregroundStyle(Color.ds.rough600)
                Text(verbatim: header.date)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.ds.canopy950)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: header.teeLine)
                Text(verbatim: header.metaLine)
            }
            .font(.system(size: 12, weight: .semibold)).tracking(12 * 0.08)
            .foregroundStyle(Color.ds.moss600)
            .lineLimit(1)
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.ds.rough600).frame(height: 2) }
    }
}

/// The scorecard table (RP-TB-01…11). Column widths and row heights are the design's, scaled so the table
/// fills the card under the header (RP-TB-11).
private struct RoundPDFTable: View {
    let model: RoundPDFModel

    /// Design widths and heights for the layout (RP-TB-01, 02, 11), at the design's 742 pt table width.
    private var metrics: RoundPDFMetrics { RoundPDFMetrics(layout: model.layout) }

    var body: some View {
        GeometryReader { proxy in
            let scale = metrics.scale(for: proxy.size)
            VStack(spacing: 0) {
                ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                    RoundPDFRow(row: row, columns: model.columns, metrics: metrics, scale: scale,
                                isLast: index == model.rows.count - 1)
                }
            }
            .frame(width: proxy.size.width, alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.ds.borderLine, lineWidth: 1))
        }
    }
}

/// One row: its label, then a cell per column, separated by hairlines.
private struct RoundPDFRow: View {
    let row: RoundPDFModel.Row
    let columns: [RoundPDFModel.Column]
    let metrics: RoundPDFMetrics
    let scale: RoundPDFMetrics.Scale
    let isLast: Bool

    var body: some View {
        HStack(spacing: 0) {
            label
                .padding(.leading, 8)
                .frame(width: metrics.labelWidth * scale.width, alignment: .leading)
            ForEach(Array(zip(columns, row.cells).enumerated()), id: \.offset) { _, pair in
                RoundPDFCell(cell: pair.1, column: pair.0, row: row.kind, metrics: metrics)
                    .frame(width: metrics.width(of: pair.0) * scale.width)
                    .frame(maxHeight: .infinity)
                    .background(background(pair.0))
                    .overlay(alignment: .leading) { Rectangle().fill(Color.ds.hairline).frame(width: 1) }
            }
        }
        .frame(height: metrics.height(of: row.kind) * scale.height)
        .background(rowBackground)
        .overlay(alignment: .bottom) {
            if !isLast { Rectangle().fill(divider).frame(height: 1) }
        }
    }

    @ViewBuilder private var label: some View {
        switch row.kind {
        case .player, .blank:
            Text(verbatim: row.label)
                .font(.system(size: metrics.nameSize, weight: .semibold))
                .foregroundStyle(Color.ds.canopy950)
                .lineLimit(1).truncationMode(.tail)
        case .hole, .yards, .par:
            Text(verbatim: row.label)
                .font(.system(size: 11, weight: .semibold)).tracking(11 * 0.14)
                .foregroundStyle(Color.ds.moss600)
                .lineLimit(1)
        }
    }

    private var rowBackground: Color {
        switch row.kind {
        case .hole: Color.ds.teeGreen50
        case .yards, .par: Color.ds.cardStripe
        case .player, .blank: Color.ds.white
        }
    }

    /// Total cells are shaded: Bunker 300 in the HOLE row, Bunker 100 below (RP-TB-03, 05, 09).
    private func background(_ column: RoundPDFModel.Column) -> Color {
        guard column.isTotal else { return .clear }
        return row.kind == .hole ? Color.ds.bunker300 : Color.ds.bunker100
    }

    /// Tee Green 200 under HOLE, Card Border under PAR, Hairline elsewhere (RP-TB-03).
    private var divider: Color {
        switch row.kind {
        case .hole: Color.ds.teeGreen200
        case .par: Color.ds.borderLine
        case .yards, .player, .blank: Color.ds.hairline
        }
    }
}

/// One cell: a number or label, a score mark, or nothing (RP-TB-07, RP-TB-08).
private struct RoundPDFCell: View {
    let cell: RoundPDFModel.Cell
    let column: RoundPDFModel.Column
    let row: RoundPDFModel.RowKind
    let metrics: RoundPDFMetrics

    var body: some View {
        switch cell {
        case .empty:
            Color.clear
        case .score(let score, let style):
            PrintScoreMark(score: score, style: style, size: metrics.markSize)
        case .text(let text):
            Text(verbatim: text)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(row == .yards || row == .par ? (column.isTotal ? Color.ds.canopy950 : Color.ds.moss600) : Color.ds.canopy950)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var size: CGFloat {
        switch row {
        case .player, .blank: metrics.totalSize
        case .yards: metrics.yardsSize
        case .hole, .par: metrics.numberSize
        }
    }

    private var weight: Font.Weight { row == .hole || column.isTotal ? .bold : .semibold }
}

/// The design's sizes for each layout (RP-TB-01, 02, 06, 07, 09, 11), in points at the design's table
/// width; the 9-hole layout's type is about 15 % larger.
struct RoundPDFMetrics: Equatable {
    /// How much the design's widths and heights stretch to fill the table's frame.
    struct Scale: Equatable {
        let width: CGFloat
        let height: CGFloat
    }

    let layout: RoundPDFModel.Layout

    /// The table width the design's column widths add up to.
    static let designWidth: CGFloat = 742

    var labelWidth: CGFloat { layout == .eighteen ? 86 : 110 }
    var markSize: CGFloat { layout == .eighteen ? 25 : 27 }
    var nameSize: CGFloat { layout == .eighteen ? 14 : 16 }
    var totalSize: CGFloat { layout == .eighteen ? 18 : 21 }
    var numberSize: CGFloat { layout == .eighteen ? 15 : 17 }
    var yardsSize: CGFloat { layout == .eighteen ? 12 : 14 }

    /// OUT / IN 36, TOT / +/− 40 (18 holes); TOT / +/− 64 (9 holes); holes share what's left.
    func width(of column: RoundPDFModel.Column) -> CGFloat {
        switch (layout, column) {
        case (.eighteen, .out), (.eighteen, .in): 36
        case (.eighteen, .tot), (.eighteen, .toPar): 40
        case (.nine, .out), (.nine, .in), (.nine, .tot), (.nine, .toPar): 64
        case (.eighteen, .hole): (Self.designWidth - 86 - 36 * 2 - 40 * 2) / 18
        case (.nine, .hole): (Self.designWidth - 110 - 64 * 2) / 9
        }
    }

    /// HOLE 28 / 32, YARDS 22 / 26, PAR 24 / 28, player and blank 38 / 34 (RP-TB-11).
    func height(of row: RoundPDFModel.RowKind) -> CGFloat {
        switch (layout, row) {
        case (.eighteen, .hole): 28
        case (.eighteen, .yards): 22
        case (.eighteen, .par): 24
        case (.eighteen, .player), (.eighteen, .blank): 38
        case (.nine, .hole): 32
        case (.nine, .yards): 26
        case (.nine, .par): 28
        case (.nine, .player), (.nine, .blank): 34
        }
    }

    /// The design table's height with its 4 player rows.
    var designHeight: CGFloat {
        height(of: .hole) + height(of: .yards) + height(of: .par) + CGFloat(RoundPDFModel.playerRows) * height(of: .player)
    }

    /// Stretches the design to `size`, the frame the table gets under the header.
    func scale(for size: CGSize) -> Scale {
        Scale(width: size.width / Self.designWidth, height: size.height / designHeight)
    }
}

#if DEBUG
// The page is always light and fixed in size, so there's no Dark or AX3 preview (RP-PG-03).
#Preview("18 holes, 4 players", traits: .fixedLayout(width: 792, height: 306)) {
    RoundPDFPage(model: .preview(holeCount: .eighteen, names: ["Mark", "Scottie", "Tiger", "Phil"], offsets: [0, -2, 1, 3]))
}
#Preview("9 holes, 2 players", traits: .fixedLayout(width: 792, height: 306)) {
    RoundPDFPage(model: .preview(holeCount: .nine, names: ["Mark", "Kevin"], offsets: [-1, 2]))
}
#Preview("1 player, a long name with a diacritic", traits: .fixedLayout(width: 792, height: 306)) {
    RoundPDFPage(model: .preview(holeCount: .eighteen, names: ["Bartholomew-Ångström"]))
}
#Preview("3 players: under, even and over par", traits: .fixedLayout(width: 792, height: 306)) {
    RoundPDFPage(model: .preview(holeCount: .nine, names: ["José", "Ann", "Chris"], offsets: [-3, -1, 2]))
}
#Preview("No weather, no duration, unscored holes", traits: .fixedLayout(width: 792, height: 306)) {
    RoundPDFPage(model: .preview(holeCount: .eighteen, names: ["Mark", "Tiger"], thru: 12, weather: nil))
}
#endif
