//
//  LatestScoresCard.swift
//  MaynardGolf
//

import Charts
import MaynardUI
import SwiftUI

/// "Latest Scores" (PC-LS-01…08, #251): the last 10 scores with the selected hole count as a Blue line over a
/// 10 % area, with a point on every round, three gridlines, a dashed rule at the average, the best round in
/// orange and the newest in Blue, each with its score under it, and three dates below. With fewer than 2 rounds
/// a hint replaces the chart. The header's trailing text button ("Show 9 holes" / "Show 18 holes") is the card's
/// only 9 / 18 control (PC-LS-01, PC-ST-04); the graph animates to the other series. Read by VoiceOver as one summary.
/// Under the graph (or the hint), All-time best and Average for the selected hole count from every completed round,
/// not only the 10 plotted (PC-ST-01…03).
struct LatestScoresCard: View {
    /// Nil shows the hint (PC-LS-07).
    let series: LatestScores?
    /// "74" or "—" (PC-ST-03, 07).
    let best: String
    /// "78.9" or "—" (PC-ST-02, 07).
    let average: String
    /// The hole count shown; the button offers the other one.
    let holeCount: HoleCount
    /// Switches the hole count (PC-ST-04).
    let toggleHoles: () -> Void
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 170
    /// The row under the plot that holds the dates.
    @ScaledMetric(relativeTo: .caption) private var captionHeight: CGFloat = 22

    var body: some View {
        ContentCard {
            // Side by side on their baselines; the button drops under the title when both don't fit (AX sizes).
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.m) {
                    title
                    Spacer(minLength: 0)
                    holesButton
                }
                VStack(alignment: .leading, spacing: 0) {
                    title
                    holesButton
                }
            }
            if let series {
                chart(series)
            } else {
                Text("Play 2 rounds to see your latest scores",
                     comment: "Player card: shown instead of the Latest Scores graph with fewer than 2 rounds of the selected hole count.")
                    .dsFont(.body)
                    .foregroundStyle(Color.ds.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("playerCard.latestScores.hint")
            }
            stats
        }
    }

    /// All-time best | Average, two equal tiles (PC-ST-01).
    private var stats: some View {
        HStack(spacing: DSSpacing.sm) {
            PlayerCardStat(value: best, caption: String(localized: "All-time best",
                                                         comment: "Player card: caption under the lowest score of every round with the selected hole count."))
                .accessibilityIdentifier("playerCard.stat.best")
            PlayerCardStat(value: average, caption: String(localized: "Average",
                                                            comment: "Player card: caption under the average score of every round with the selected hole count."))
                .accessibilityIdentifier("playerCard.stat.avg")
        }
    }

    private var title: some View {
        Text("Latest Scores", comment: "Player card: the title of the graph of the player's latest scores.")
            .dsFont(.section)
            .foregroundStyle(Color.ds.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .fixedSize()
    }

    /// "Show 9 holes" while 18 is shown, "Show 18 holes" while 9 is (PC-ST-04). Its label is the action, so UI tests
    /// read it through `playerCard.holes`.
    private var holesButton: some View {
        Button(action: toggleHoles) { Text(verbatim: PlayerCardViewModel.holesButtonTitle(showing: holeCount)) }
            .buttonStyle(.dsCompactTextLink)
            .fixedSize()
            .accessibilityIdentifier("playerCard.holes")
    }

    private static var roundAxis: Text { Text("Round", comment: "Latest Scores graph: the axis of rounds, oldest to newest (read by assistive technologies).") }
    private static var scoreAxis: Text { Text("Score", comment: "Latest Scores graph: the axis of scores (read by assistive technologies).") }

    private func chart(_ series: LatestScores) -> some View {
        Chart {
            ForEach(series.points) { point in line(point, floor: series.domain.lowerBound) }
            average(series.average)
            if series.labelsNewest {
                marker(series.newest, fill: Color.ds.emphasis, label: Color.ds.emphasis, alignment: .trailing)
            }
            // Drawn last so it sits on top; when the newest is also the best, only this one shows (PC-LS-05).
            marker(series.best, fill: Color.ds.bestScoreMarker, label: Color.ds.underPar, alignment: .center)
        }
        .chartXScale(domain: series.xDomain)
        .chartYScale(domain: series.domain)
        .chartYAxis { yAxis(series.gridlines) }
        .chartXAxis(.hidden)
        .chartOverlay { proxy in captions(series.captions, proxy: proxy) }
        .frame(height: chartHeight)
        .padding(.bottom, captionHeight)
        .animation(.easeInOut, value: series)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: series.accessibilitySummary))
        .accessibilityIdentifier("playerCard.latestScores")
    }

    /// One round: its slice of the 10 % area (from the bottom of the plot, not zero), the line and a small point.
    /// Values are `Double`s, like the scales.
    @ChartContentBuilder
    private func line(_ point: LatestScores.Point, floor: Double) -> some ChartContent {
        let x = PlottableValue.value(Self.roundAxis, Double(point.index))
        let y = PlottableValue.value(Self.scoreAxis, Double(point.gross))
        AreaMark(x: x, yStart: .value(Self.scoreAxis, floor), yEnd: y)
            .foregroundStyle(Color.ds.emphasis.opacity(0.1))
        LineMark(x: x, y: y)
            .foregroundStyle(Color.ds.emphasis)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        PointMark(x: x, y: y)
            .symbol { Circle().fill(Color.ds.emphasis).frame(width: 8, height: 8) }
    }

    /// The dashed grey rule at the plotted rounds' average (PC-LS-04).
    private func average(_ value: Double) -> some ChartContent {
        RuleMark(y: .value(Self.scoreAxis, value))
            .foregroundStyle(Color.ds.textSecondary)
            .lineStyle(StrokeStyle(lineWidth: 1.25, dash: [4, 4]))
    }

    /// Three gridlines with their scores on the leading side (PC-LS-03).
    private func yAxis(_ gridlines: [Int]) -> some AxisContent {
        AxisMarks(position: .leading, values: gridlines.map(Double.init)) { value in
            AxisGridLine().foregroundStyle(Color.ds.divider)
            AxisValueLabel {
                if let score = value.as(Double.self) {
                    Text(verbatim: "\(Int(score))").dsFont(.caption).dsNumeric().foregroundStyle(Color.ds.textSecondary)
                }
            }
        }
    }

    /// The dates under the plot, each placed from its point's x position (PC-LS-06): the first starts at its
    /// point, the newest ends at its point and the middle is centered under its point. Drawn in the row the
    /// bottom padding leaves; axis labels' anchors didn't hold these positions.
    private func captions(_ captions: [LatestScores.Caption], proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            if let plot = proxy.plotFrame.map({ geometry[$0] }) {
                ForEach(Array(captions.enumerated()), id: \.offset) { offset, caption in
                    if let x = proxy.position(forX: Double(caption.index)) {
                        Text(verbatim: caption.text).dsFont(.caption).textCase(.uppercase).foregroundStyle(Color.ds.textSecondary)
                            .fixedSize()
                            // A zero-width frame aligned to one side: the text hangs off that side of the point.
                            .frame(width: 0, alignment: Self.alignment(offset, of: captions.count))
                            .position(x: plot.minX + x, y: plot.maxY + captionHeight / 2 + DSSpacing.xxs)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// The best or newest round: a larger point with a ring in the card's color and its score under it.
    private func marker(_ point: LatestScores.Point, fill: Color, label: Color, alignment: Alignment) -> some ChartContent {
        PointMark(x: .value(Self.roundAxis, Double(point.index)), y: .value(Self.scoreAxis, Double(point.gross)))
            .symbol {
                Circle().fill(fill).frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(Color.ds.surfaceCard, lineWidth: 2))
            }
            .annotation(position: .bottom, alignment: alignment, spacing: DSSpacing.xxs,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                Text(verbatim: "\(point.gross)").dsFont(.bodyEmphasized).dsNumeric().foregroundStyle(label)
            }
    }

    /// The first caption hangs right of its point, the last left of it, the middle centered under it.
    private static func alignment(_ offset: Int, of count: Int) -> Alignment {
        switch offset {
        case 0: .leading
        case count - 1: .trailing
        default: .center
        }
    }
}

/// One stat tile under Latest Scores (PC-ST-02, 03): a 22 pt bold `emphasis` value over a caption, centered on a
/// `surfaceRaised` tile, read as "Average, 78.9".
struct PlayerCardStat: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: value).dsFont(.section).dsNumeric().foregroundStyle(Color.ds.emphasis).lineLimit(1)
            Text(verbatim: caption).dsFont(.caption).foregroundStyle(Color.ds.textSecondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.sm)
        .padding(.horizontal, DSSpacing.s)
        .background(RoundedRectangle(cornerRadius: DSRadius.chipTile, style: .continuous).fill(Color.ds.surfaceRaised))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(caption), \(value)"))
    }
}

#if DEBUG
/// A series from `gross`, newest last, one a week up to the preview date.
private func series(_ gross: [Int], _ holeCount: HoleCount = .eighteen) -> LatestScores? {
    let scores = gross.enumerated().map { offset, value in
        PlayerRoundScore(id: UUID(), date: ModelFixtures.daysAgo((gross.count - 1 - offset) * 7), holeCount: holeCount, gross: value)
    }
    return LatestScores.make(scores, holeCount: holeCount)
}

private func card(_ series: LatestScores?, showing holeCount: HoleCount = .eighteen, best: String = "74", average: String = "78.9") -> some View {
    LatestScoresCard(series: series, best: best, average: average, holeCount: holeCount) {}.padding(DSSpacing.gutter).background(Color.ds.background)
}

/// The card with a working button, switching between an 18-hole and a 9-hole series.
private struct TogglingCard: View {
    @State private var holeCount: HoleCount = .eighteen

    var body: some View {
        LatestScoresCard(series: holeCount == .nine ? series([44, 41, 47, 39, 42, 40], .nine) : series([82, 79, 83, 76, 80, 78]),
                         best: holeCount == .nine ? "37" : "74", average: holeCount == .nine ? "41.2" : "78.9", holeCount: holeCount) { withAnimation { holeCount = holeCount == .nine ? .eighteen : .nine } }
            .padding(DSSpacing.gutter).background(Color.ds.background)
    }
}

#Preview("Showing 18: Show 9 holes") { card(series([82, 79, 83, 76, 80, 78, 81, 74, 79, 77])) }
#Preview("2 rounds") { card(series([81, 78])) }
#Preview("Fewer than 2 rounds: hint") { card(nil, best: "81", average: "81.0") }
#Preview("No rounds: hint and dashes") { card(nil, best: "—", average: "—") }
#Preview("Newest is best") { card(series([84, 81, 83, 79, 76])) }
#Preview("All the same score") { card(series([80, 80, 80, 80])) }
#Preview("Showing 9: Show 18 holes") { card(series([44, 41, 47, 39, 42, 40], .nine), showing: .nine, best: "37", average: "41.2") }
#Preview("Toggling 18 ↔ 9") { TogglingCard() }
#Preview("High scores") { card(series([104, 112, 99, 108, 101, 117])) }
#Preview("Dark, AX3") {
    card(series([82, 79, 83, 76, 80, 78, 81, 74, 79, 77]))
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
#endif
