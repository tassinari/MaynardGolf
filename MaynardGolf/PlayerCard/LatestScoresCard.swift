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
/// a hint replaces the chart. It animates when the 9 / 18 toggle changes. Read by VoiceOver as one summary.
struct LatestScoresCard: View {
    /// Nil shows the hint (PC-LS-07).
    let series: LatestScores?
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 170
    /// The row under the plot that holds the dates.
    @ScaledMetric(relativeTo: .caption) private var captionHeight: CGFloat = 22

    var body: some View {
        ContentCard {
            Text("Latest Scores", comment: "Player card: the title of the graph of the player's latest scores.")
                .dsFont(.section)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
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
        }
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
            .symbol { Circle().fill(Color.ds.primaryAction).frame(width: 8, height: 8) }
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

#if DEBUG
/// A series from `gross`, newest last, one a week up to the preview date, with an outside score at `outside`.
private func series(_ gross: [Int], _ holeCount: HoleCount = .eighteen, outside: Int? = nil) -> LatestScores? {
    let scores = gross.enumerated().map { offset, value in
        LatestScores.Score(id: UUID(), date: ModelFixtures.daysAgo((gross.count - 1 - offset) * 7), holeCount: holeCount, gross: value,
                           isOutside: offset == outside)
    }
    return LatestScores.make(scores, holeCount: holeCount)
}

private func card(_ series: LatestScores?) -> some View {
    LatestScoresCard(series: series).padding(DSSpacing.gutter).background(Color.ds.background)
}

#Preview("10 rounds, one outside") { card(series([82, 79, 83, 76, 80, 78, 81, 74, 79, 77], outside: 4)) }
#Preview("2 rounds") { card(series([81, 78])) }
#Preview("Fewer than 2 rounds: hint") { card(nil) }
#Preview("Newest is best") { card(series([84, 81, 83, 79, 76])) }
#Preview("All the same score") { card(series([80, 80, 80, 80])) }
#Preview("Nine holes") { card(series([44, 41, 47, 39, 42, 40], .nine)) }
#Preview("High scores") { card(series([104, 112, 99, 108, 101, 117])) }
#Preview("Dark, AX3") {
    card(series([82, 79, 83, 76, 80, 78, 81, 74, 79, 77]))
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
#endif
