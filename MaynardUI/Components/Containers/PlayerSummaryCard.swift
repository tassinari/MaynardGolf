//
//  PlayerSummaryCard.swift
//  MaynardUI
//

import Charts
import SwiftUI
import UIKit

/// The Home card for one or two players (DS-CN-10, 01-home §4.4): avatar, name over "Last played …",
/// the handicap index, three stat tiles and an optional compact 12-month handicap chart. The whole card
/// is one button, so the caller wraps it in a `Button` or `NavigationLink`.
public struct PlayerSummaryCard: View {
    /// One point of the handicap chart.
    public struct HandicapPoint: Identifiable, Sendable {
        public let date: Date
        public let index: Double
        public var id: Date { date }

        public init(date: Date, index: Double) {
            self.date = date
            self.index = index
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
    private let chart: [HandicapPoint]

    public init(name: String, color: PlayerPalette, photo: UIImage? = nil, lastPlayed: Date?, handicapIndex: Double?,
                average: String, best: String, lastRound: String, chart: [HandicapPoint] = []) {
        self.name = name
        self.color = color
        self.photo = photo
        self.lastPlayed = lastPlayed
        self.handicapIndex = handicapIndex
        self.average = average
        self.best = best
        self.lastRound = lastRound
        self.chart = chart
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.l) {
            HStack(alignment: .top, spacing: DSSpacing.m) {
                PlayerAvatar(name: name, color: color, photo: photo, size: .summary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: name).font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.ds.textPrimary)
                    Text(verbatim: DisplayFormatting.lastPlayed(lastPlayed)).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                }
                Spacer(minLength: DSSpacing.s)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: Self.indexLabel).dsFont(.labelSmall).foregroundStyle(Color.ds.textSecondary)
                    Text(verbatim: DisplayFormatting.handicapIndex(handicapIndex)).dsFont(.numeral)
                        .foregroundStyle(Color.ds.primaryAction)
                }
            }
            HStack(spacing: DSSpacing.s) {
                StatTile(value: average, caption: Text(verbatim: Self.averageLabel))
                StatTile(value: best, caption: Text(verbatim: Self.bestLabel))
                StatTile(value: lastRound, caption: Text(verbatim: Self.lastRoundLabel))
            }
            if chart.count > 1 {
                Chart(chart) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Index", point.index))
                        .foregroundStyle(Color.ds.primaryAction)
                        .interpolationMethod(.monotone)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 70)
                .accessibilityHidden(true) // the index above carries the number
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.ds.surfaceCard))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.ds.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
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
}
