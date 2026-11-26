//
//  PlayerSummaryCard.swift
//  MaynardUI
//

import Charts
import SwiftUI
import UIKit

/// The Home card for one or two players (DS-CN-13, 01-home §4.4): avatar, name over "Last played …",
/// the handicap index, three stat tiles and an optional compact 12-month handicap chart. The whole card
/// is one button, so the caller wraps it in a `Button` or `NavigationLink`. It reads as one accessibility
/// element whose label the caller builds (HOME-PC-04), because only the app knows whether the index was
/// calculated.
public struct PlayerSummaryCard: View {
    /// One point of the handicap chart. Points are identified by their date, so dates must be unique (one
    /// index per day, which is how the handicap history is kept).
    public struct HandicapPoint: Identifiable, Sendable, Equatable {
        public let date: Date
        public let index: Double
        public var id: Date { date }

        public init(date: Date, index: Double) {
            self.date = date
            self.index = index
        }
    }

    /// The compact handicap chart (HOME-PC-06, 07): the points, the "11.2 → 8.4" range and the month
    /// labels (first, middle, last; first and last with only two points). The card draws it only with 2 points or more (HOME-PC-08).
    public struct Chart: Sendable, Equatable {
        public let points: [HandicapPoint]
        public let range: String
        public let monthLabels: [String]

        public init(points: [HandicapPoint], range: String, monthLabels: [String]) {
            self.points = points
            self.range = range
            self.monthLabels = monthLabels
        }
    }

    private let name: String
    private let color: PlayerPalette
    private let photo: UIImage?
    private let lastPlayed: Date?
    private let handicapIndex: Double?
    private let average: String
    private let best: String
    private let lastRound: String
    private let chart: Chart?
    private let accessibilitySummary: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameter accessibilitySummary: what VoiceOver reads for the whole card (HOME-PC-04); nil reads
    ///   the visible text.
    public init(name: String, color: PlayerPalette, photo: UIImage? = nil, lastPlayed: Date?, handicapIndex: Double?,
                average: String, best: String, lastRound: String, chart: Chart? = nil, accessibilitySummary: String? = nil) {
        self.name = name
        self.color = color
        self.photo = photo
        self.lastPlayed = lastPlayed
        self.handicapIndex = handicapIndex
        self.average = average
        self.best = best
        self.lastRound = lastRound
        self.chart = chart
        self.accessibilitySummary = accessibilitySummary
    }

    public var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: DSSpacing.ml) {
            // At accessibility sizes the index moves under the name and the tiles stack (HOME-PC-05).
            if stacked {
                HStack(alignment: .top, spacing: DSSpacing.m) {
                    PlayerAvatar(name: name, color: color, photo: photo, size: .summary)
                    identity
                }
                index(alignment: .leading)
                VStack(spacing: DSSpacing.s) { tiles }
            } else {
                HStack(alignment: .top, spacing: DSSpacing.m) {
                    PlayerAvatar(name: name, color: color, photo: photo, size: .summary)
                    identity
                    Spacer(minLength: DSSpacing.s)
                    index(alignment: .trailing)
                }
                HStack(spacing: DSSpacing.s) { tiles }
            }
            if let chart, chart.points.count > 1 {
                chartSection(chart)
            }
        }
        .padding(DSSpacing.lx)
        .background(RoundedRectangle(cornerRadius: DSRadius.summaryCard, style: .continuous).fill(Color.ds.surfaceCard))
        .dsCardElevation(cornerRadius: DSRadius.summaryCard)
        .contentShape(RoundedRectangle(cornerRadius: DSRadius.summaryCard, style: .continuous))
        .accessibilityElement(children: .combine)
        .modifier(SummaryLabel(summary: accessibilitySummary))
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: name).dsFont(.cardName).foregroundStyle(Color.ds.textPrimary).lineLimit(stackedLineLimit)
            Text(verbatim: DisplayFormatting.lastPlayed(lastPlayed)).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
        }
    }

    /// One line at regular sizes (HOME-PC-02), wrapping at accessibility sizes so nothing truncates.
    private var stackedLineLimit: Int? { dynamicTypeSize.isAccessibilitySize ? nil : 1 }

    private func index(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(verbatim: Self.indexLabel).dsFont(.labelSmall).foregroundStyle(Color.ds.textSecondary)
            Text(verbatim: DisplayFormatting.handicapIndex(handicapIndex)).dsFont(.numeral).dsNumeric()
                .foregroundStyle(Color.ds.emphasis)
        }
    }

    @ViewBuilder private var tiles: some View {
        StatTile(value: average, caption: Text(verbatim: Self.averageLabel))
        StatTile(value: best, caption: Text(verbatim: Self.bestLabel))
        StatTile(value: lastRound, caption: Text(verbatim: Self.lastRoundLabel))
    }

    /// The chart under a hairline (HOME-PC-06, 07): title and range, the 70 pt line and area with a dot on
    /// the last point, then the first, middle and last month labels.
    private func chartSection(_ chart: Chart) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            DSDivider()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { chartTitle; Spacer(minLength: DSSpacing.s); chartRange(chart) }
                VStack(alignment: .leading, spacing: 2) { chartTitle; chartRange(chart) }
            }
            .padding(.top, DSSpacing.xxs)
            let domain = Self.domain(chart.points)
            Charts.Chart {
                ForEach(chart.points) { point in
                    // The area starts at the bottom of the visible range, not at zero, so it stays in the plot.
                    AreaMark(x: .value(Self.dateAxisLabel, point.date),
                             yStart: .value(Self.indexAxisLabel, domain.lowerBound),
                             yEnd: .value(Self.indexAxisLabel, point.index))
                        .foregroundStyle(Color.ds.emphasis.opacity(0.1))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value(Self.dateAxisLabel, point.date), y: .value(Self.indexAxisLabel, point.index))
                        .foregroundStyle(Color.ds.emphasis)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
                if let last = chart.points.last {
                    PointMark(x: .value(Self.dateAxisLabel, last.date), y: .value(Self.indexAxisLabel, last.index))
                        .symbol {
                            Circle().fill(Color.ds.primaryAction).frame(width: 9, height: 9)
                                .overlay(Circle().strokeBorder(Color.ds.surfaceCard, lineWidth: 2))
                        }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: domain)
            .chartPlotStyle { $0.clipped() }
            .frame(height: 70)
            HStack {
                ForEach(Array(chart.monthLabels.enumerated()), id: \.offset) { offset, label in
                    if offset > 0 { Spacer(minLength: DSSpacing.s) }
                    Text(verbatim: label).dsFont(.caption).textCase(.uppercase).foregroundStyle(Color.ds.textSecondary)
                }
            }
        }
    }

    private var chartTitle: some View {
        Text(verbatim: Self.chartTitle).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
    }

    private func chartRange(_ chart: Chart) -> some View {
        Text(verbatim: chart.range).dsFont(.caption).dsNumeric().foregroundStyle(Color.ds.textSecondary)
    }

    /// The y range with a little room above and below, so the line never touches the frame and a flat
    /// series still draws in the middle.
    nonisolated static func domain(_ points: [HandicapPoint]) -> ClosedRange<Double> {
        let values = points.map(\.index)
        let low = values.min() ?? 0, high = values.max() ?? 0
        let pad = max((high - low) * 0.15, 0.5)
        return (low - pad)...(high + pad)
    }

    /// The chart's axis names, from the MaynardUI catalog (a plain key would look in the app's bundle).
    public nonisolated static var dateAxisLabel: String {
        String(localized: "Date", bundle: Bundle.maynardUI, comment: "Axis name of the handicap chart's dates (read by assistive technologies).")
    }
    public nonisolated static var indexAxisLabel: String {
        String(localized: "Index", bundle: Bundle.maynardUI, comment: "Axis name of the handicap chart's index values (read by assistive technologies).")
    }

    public nonisolated static var indexLabel: String {
        String(localized: "HCP index", bundle: Bundle.maynardUI, comment: "Label over the handicap index on the player card, shown in caps.")
    }
    public nonisolated static var averageLabel: String {
        String(localized: "Avg score", bundle: Bundle.maynardUI, comment: "Stat tile caption: average score.")
    }
    public nonisolated static var bestLabel: String {
        String(localized: "Best", bundle: Bundle.maynardUI, comment: "Stat tile caption: best score.")
    }
    public nonisolated static var lastRoundLabel: String {
        String(localized: "Last round", bundle: Bundle.maynardUI, comment: "Stat tile caption: score of the last round.")
    }
    /// "HANDICAP · 12 MONTHS" over the chart (HOME-PC-06).
    public nonisolated static var chartTitle: String {
        String(localized: "Handicap · 12 months", bundle: Bundle.maynardUI, comment: "Title over the 12-month handicap chart on the player summary card.")
    }
}

/// Replaces the combined label with the caller's summary when there is one.
private struct SummaryLabel: ViewModifier {
    let summary: String?

    func body(content: Content) -> some View {
        if let summary {
            content.accessibilityLabel(Text(verbatim: summary))
        } else {
            content
        }
    }
}
