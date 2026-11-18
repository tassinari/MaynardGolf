//
//  HandicapTrendCard.swift
//  MaynardGolf
//

import Charts
import MaynardUI
import SwiftUI

/// "HANDICAP · 12 MONTHS" (PC-HC-01…06): the calculated index at each month end as a Lake line over a 10 %
/// area, three gridlines, a ringed dot with its value on the last point, and the first, middle and last
/// months under it. Read by VoiceOver as one summary. The caller leaves it out under 2 points (PC-HC-06).
struct HandicapTrendCard: View {
    let trend: HandicapTrend
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 150

    var body: some View {
        ContentCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { title; Spacer(minLength: DSSpacing.s); range }
                VStack(alignment: .leading, spacing: 2) { title; range }
            }
            chart
            HStack {
                ForEach(Array(trend.chart.monthLabels.enumerated()), id: \.offset) { offset, label in
                    if offset > 0 { Spacer(minLength: DSSpacing.s) }
                    Text(verbatim: label).dsFont(.label).textCase(.uppercase).foregroundStyle(Color.ds.textSecondary)
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: trend.chart.accessibilitySummary))
        .accessibilityIdentifier("playerCard.handicapChart")
    }

    private var title: some View {
        Text(verbatim: PlayerSummaryCard.chartTitle).dsFont(.section).textCase(.uppercase).foregroundStyle(Color.ds.textPrimary)
    }

    private var range: some View {
        Text(verbatim: trend.chart.range).dsFont(.caption).dsNumeric().foregroundStyle(Color.ds.textSecondary)
    }

    private var chart: some View {
        Chart {
            ForEach(trend.chart.points) { point in
                // The area starts at the bottom gridline, not at zero, so it stays in the plot.
                AreaMark(x: .value(PlayerSummaryCard.dateAxisLabel, point.date),
                         yStart: .value(PlayerSummaryCard.indexAxisLabel, trend.domain.lowerBound),
                         yEnd: .value(PlayerSummaryCard.indexAxisLabel, point.index))
                    .foregroundStyle(Color.ds.primaryAction.opacity(0.1))
                    .interpolationMethod(.monotone)
                LineMark(x: .value(PlayerSummaryCard.dateAxisLabel, point.date), y: .value(PlayerSummaryCard.indexAxisLabel, point.index))
                    .foregroundStyle(Color.ds.primaryAction)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let last = trend.chart.points.last {
                PointMark(x: .value(PlayerSummaryCard.dateAxisLabel, last.date), y: .value(PlayerSummaryCard.indexAxisLabel, last.index))
                    .symbol {
                        Circle().fill(Color.ds.primaryAction).frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(Color.ds.surfaceCard, lineWidth: 2))
                    }
                    .annotation(position: .top, alignment: .trailing, spacing: DSSpacing.xs) {
                        Text(verbatim: trend.lastLabel()).dsFont(.bodyEmphasized).dsNumeric().foregroundStyle(Color.ds.textPrimary)
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: trend.gridlines) { value in
                AxisGridLine().foregroundStyle(Color.ds.divider)
                AxisValueLabel {
                    if let index = value.as(Double.self) {
                        Text(verbatim: HandicapTrend.gridlineLabel(index))
                            .dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                    }
                }
            }
        }
        .chartYScale(domain: trend.domain)
        .frame(height: chartHeight)
    }
}

#if DEBUG
/// A trend over `values`, one a month ending at the preview date.
private func trend(_ values: [Double]) -> HandicapTrend? {
    let end = ModelFixtures.referenceDate
    return HandicapTrend.make(values.enumerated().map { offset, value in
        PlayerSummaryCard.HandicapPoint(date: Calendar.current.date(byAdding: .month, value: offset - values.count + 1, to: end) ?? end,
                                        index: value)
    })
}

@ViewBuilder
private func card(_ trend: HandicapTrend?) -> some View {
    if let trend {
        HandicapTrendCard(trend: trend).padding(DSSpacing.gutter).background(Color.ds.background)
    }
}

#Preview("Dense: 12 months falling") { card(trend([11.2, 11.0, 10.9, 10.6, 10.4, 10.1, 9.8, 9.6, 9.3, 9.0, 8.7, 8.4])) }
#Preview("Sparse: 2 months") { card(trend([12.3, 11.8])) }
#Preview("Flat") { card(trend([8.4, 8.4, 8.4, 8.4])) }
#Preview("Plus handicap rising") { card(trend([-3.1, -2.8, -2.5, -2.4, -2.1])) }
#Preview("Dark, AX3") {
    card(trend([11.2, 10.9, 10.4, 9.8, 9.3, 8.7, 8.4]))
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
#endif
