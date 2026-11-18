//
//  GolfDisplay.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// A score numeral marked by its relation to par (DS-GF-01): circles under par, squares over, a "·"
/// when the hole isn't played. The mark grows with Dynamic Type like the score numeral, up to XXXL.
public struct ScoreMark: View {
    private let score: Int?
    private let par: Int
    private let size: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// `size` is the mark's side at the default text size, 26–30 pt.
    public init(score: Int?, par: Int, size: CGFloat = 28) {
        self.score = score
        self.par = par
        self.size = size
    }

    public var body: some View {
        let style = ScoreFormatter.markStyle(score: score, par: par)
        let side = Self.scaledSide(size, category: UIContentSizeCategory(dynamicTypeSize))
        ZStack {
            ScoreMarkShape(style: style, inset: Self.ringGap(for: side))
            Text(verbatim: score.map(String.init) ?? "·")
                .dsFont(.scoreNumeral)
                .foregroundStyle(Color(style.foreground))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(width: side, height: side)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: ScoreFormatter.spokenScore(score, par: par)))
    }

    /// The side at a content size: scaled with the score numeral, so the numeral keeps fitting.
    nonisolated static func scaledSide(_ size: CGFloat, category: UIContentSizeCategory) -> CGFloat {
        size * DSTextStyle.scoreNumeral.scaledSize(for: category) / DSTextStyle.scoreNumeral.size
    }

    /// The gap between the double circle's rings.
    nonisolated static func ringGap(for side: CGFloat) -> CGFloat { (side * 0.11).rounded() }
}

/// A score mark for print (the round PDF, RP-TB-07, RP-AR-04): the same shapes and tokens as `ScoreMark`,
/// at a fixed size that ignores Dynamic Type (RP-PG-03), with the numeral in the mark's color
/// (`MarkStyle.printForeground`). The page forces Light, so the semantic tokens resolve to the light palette.
public struct PrintScoreMark: View {
    private let score: Int
    private let style: ScoreFormatter.MarkStyle
    private let size: CGFloat

    /// `size` is the mark's side in points; the numeral is 68 % of it, bold, as in the design.
    public init(score: Int, style: ScoreFormatter.MarkStyle, size: CGFloat) {
        self.score = score
        self.style = style
        self.size = size
    }

    public var body: some View {
        ZStack {
            ScoreMarkShape(style: style, inset: ScoreMark.ringGap(for: size))
            Text(verbatim: "\(score)")
                .font(.system(size: (size * 0.68).rounded(), weight: .bold))
                .foregroundStyle(Color(style.printForeground))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(width: size, height: size)
    }
}

/// The outline and fill of a score mark, without the numeral (also the legend's swatches). The colors
/// come from the style's `stroke` and `fill` tokens only, so the tested tokens are the drawn ones.
struct ScoreMarkShape: View {
    let style: ScoreFormatter.MarkStyle
    let inset: CGFloat

    var body: some View {
        switch style {
        case .doubleCircle:
            Circle().fill(color(style.fill))
                .overlay(Circle().strokeBorder(color(style.stroke), lineWidth: 1.5))
                .overlay(Circle().inset(by: inset).strokeBorder(color(style.stroke), lineWidth: 1.5))
        case .circle:
            Circle().fill(color(style.fill)).overlay(Circle().strokeBorder(color(style.stroke), lineWidth: 1.5))
        case .square, .filledSquare:
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(color(style.fill))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(color(style.stroke), lineWidth: 1.5))
        case .plain, .empty:
            Color.clear
        }
    }

    /// A token's color, or clear when the style has none for that part.
    private func color(_ token: DSColorToken?) -> Color { token.map(Color.init) ?? .clear }
}

/// The scorecard key: Eagle, Birdie, Bogey, Double+ swatches with labels (DS-GF-02, SC-PT-07).
public struct ScoreLegend: View {
    /// One key entry.
    public enum Item: CaseIterable, Sendable {
        case eagle, birdie, bogey, doublePlus

        var style: ScoreFormatter.MarkStyle {
            switch self {
            case .eagle: .doubleCircle
            case .birdie: .circle
            case .bogey: .square
            case .doublePlus: .filledSquare
            }
        }

        public var title: String {
            switch self {
            case .eagle: ScoreFormatter.ScoreName.eagle.title
            case .birdie: ScoreFormatter.ScoreName.birdie.title
            case .bogey: ScoreFormatter.ScoreName.bogey.title
            case .doublePlus: String(localized: "Double+", bundle: Bundle.maynardUI,
                                     comment: "Scorecard legend: double bogey or worse.")
            }
        }
    }

    private let items: [Item]
    @ScaledMetric(relativeTo: .caption) private var swatch: CGFloat = 14

    public init(items: [Item] = Item.allCases) { self.items = items }

    public var body: some View {
        FlowLayout(spacing: DSSpacing.m) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: DSSpacing.xs) {
                    ScoreMarkShape(style: item.style, inset: 3)
                        .frame(width: swatch, height: swatch)
                        .accessibilityHidden(true)
                    Text(verbatim: item.title).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// "E", "+n" or "−n" in the color for its surface (DS-GF-03).
public struct ToParText: View {
    /// Where the text sits, which decides its colors.
    public enum Surface: Sendable, Equatable {
        /// A card or list. `emphasized` uses `textPrimary` for par and over, where the design shows it bold.
        case app(emphasized: Bool = false)
        /// Glass or an aerial photo, in both appearances.
        case imagery
    }

    private let value: Int
    private let surface: Surface
    private let style: DSTextStyle

    public init(value: Int, surface: Surface = .app(), style: DSTextStyle = .bodyEmphasized) {
        self.value = value
        self.surface = surface
        self.style = style
    }

    public var body: some View {
        Text(verbatim: ScoreFormatter.toPar(value))
            .dsFont(style)
            .dsNumeric()
            .foregroundStyle(Color(Self.color(for: value, on: surface)))
            .accessibilityLabel(Text(verbatim: ScoreFormatter.spokenToPar(value)))
    }

    /// Under par: `underPar` on app surfaces, Flag 400 on imagery. Par and over: `textSecondary`
    /// (`textPrimary` when emphasized) on app surfaces, Chalk 50 on imagery.
    public nonisolated static func color(for value: Int, on surface: Surface) -> DSColorToken {
        switch (surface, value < 0) {
        case (.app, true): .underPar
        case (.app(let emphasized), false): emphasized ? .textPrimary : .textSecondary
        case (.imagery, true): .flag400
        case (.imagery, false): .chalk50
        }
    }
}

/// A capsule with the score name: "BIRDIE", "PAR", "DOUBLE" (DS-GF-04, HP-ES-05).
public struct ScoreNameBadge: View {
    private let name: ScoreFormatter.ScoreName

    public init(_ name: ScoreFormatter.ScoreName) { self.name = name }

    /// The badge for a score on a hole.
    public init(score: Int, par: Int) { self.init(ScoreFormatter.scoreName(score: score, par: par)) }

    public var body: some View {
        let colors = Self.colors(for: name.tone)
        Text(verbatim: name.title)
            .dsFont(.label)
            .foregroundStyle(Color(colors.text))
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(Capsule().fill(Color(colors.fill)))
            .accessibilityLabel(Text(verbatim: name.title))
    }

    /// Under par Flag 600 / white, par Chalk 200 / Canopy 950, over Lake 600 / white.
    public nonisolated static func colors(for tone: ScoreFormatter.ScoreName.Tone) -> (fill: DSColorToken, text: DSColorToken) {
        switch tone {
        case .under: (.flag600, .white)
        case .par: (.chalk200, .canopy950)
        case .over: (.lake600, .white)
        }
    }
}

/// A weather symbol with an optional temperature: "☀︎ 62°" (DS-GF-05, SC-HDR-05). It takes the app's five
/// weather kinds; the WeatherKit mapping is `WeatherKind(weatherKit:)` in the data layer (DM-EN-04).
public struct WeatherIcon: View {
    /// The five kinds, with the same raw values as the stored `WeatherKind`.
    public enum Kind: String, CaseIterable, Sendable {
        case sunny, partlyCloudy, cloudy, rain, windy

        public var symbolName: String {
            switch self {
            case .sunny: "sun.max.fill"
            case .partlyCloudy: "cloud.sun.fill"
            case .cloudy: "cloud.fill"
            case .rain: "cloud.rain.fill"
            case .windy: "wind"
            }
        }

        public var title: String {
            switch self {
            case .sunny: String(localized: "Sunny", bundle: Bundle.maynardUI, comment: "Weather condition.")
            case .partlyCloudy: String(localized: "Partly cloudy", bundle: Bundle.maynardUI, comment: "Weather condition.")
            case .cloudy: String(localized: "Cloudy", bundle: Bundle.maynardUI, comment: "Weather condition.")
            case .rain: String(localized: "Rain", bundle: Bundle.maynardUI, comment: "Weather condition.")
            case .windy: String(localized: "Windy", bundle: Bundle.maynardUI, comment: "Weather condition.")
            }
        }
    }

    private let kind: Kind
    private let temperature: Int?

    /// `temperature` is in whole degrees, as stored with the round.
    public init(_ kind: Kind, temperature: Int? = nil) {
        self.kind = kind
        self.temperature = temperature
    }

    public var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            Image(systemName: kind.symbolName).symbolRenderingMode(.hierarchical)
            if let temperature {
                Text(verbatim: "\(temperature)°").dsNumeric()
            }
        }
        .dsFont(.bodyEmphasized)
        .foregroundStyle(Color.ds.textSecondary)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: Self.accessibilityLabel(kind, temperature: temperature)))
    }

    /// "Sunny, 62 degrees", or "Sunny" without a temperature.
    public nonisolated static func accessibilityLabel(_ kind: Kind, temperature: Int?) -> String {
        guard let temperature else { return kind.title }
        return String(localized: "\(kind.title), \(temperature) degrees", bundle: Bundle.maynardUI,
                      comment: "VoiceOver: weather condition and temperature, e.g. 'Sunny, 62 degrees'.")
    }
}

/// A 14 pt dot in a tee's color (DS-GF-06). It always sits beside the tee's name, so VoiceOver skips it.
public struct TeeDot: View {
    /// Maynard GC's tees, with the same raw values as the stored `Tee`.
    public enum Tee: String, CaseIterable, Sendable {
        case blue, white, yellow, red

        /// The dot's fill: Lake 600, White, Bunker 300 and Flag 600.
        public var fill: DSColorToken {
            switch self {
            case .blue: .lake600
            case .white: .white
            case .yellow: .bunker300
            case .red: .flag600
            }
        }

        /// White tees get a Moss 400 ring so the dot shows on white and Chalk.
        public var ring: DSColorToken? { self == .white ? .moss400 : nil }
    }

    private let tee: Tee
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 14

    public init(_ tee: Tee) { self.tee = tee }

    public var body: some View {
        Circle().fill(Color(tee.fill))
            .overlay {
                if let ring = tee.ring { Circle().strokeBorder(Color(ring), lineWidth: 1.5) }
            }
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)
    }
}

/// The hole card on the hole map (DS-GF-07, HP-HOLE-01): a 60 pt hole badge, then "PAR 4", "380 YDS"
/// and "HCP 7" on glass. Yardage is always yards, for the round's tee.
public struct HoleInfoCard: View {
    private let number: Int
    private let par: Int
    private let yards: Int
    private let handicap: Int

    public init(number: Int, par: Int, yards: Int, handicap: Int) {
        self.number = number
        self.par = par
        self.yards = yards
        self.handicap = handicap
    }

    public var body: some View {
        HStack(spacing: DSSpacing.s) {
            HoleNumberBadge(number: number, size: .large)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: Self.parText(par)).dsFont(.holeStat).foregroundStyle(Color.ds.chalk50)
                Text(verbatim: Self.yardsText(yards)).dsFont(.holeYards).foregroundStyle(Color.ds.chalk50)
                Text(verbatim: Self.handicapText(handicap)).dsFont(.holeHandicap).foregroundStyle(Color.ds.lake100)
            }
            .textCase(.uppercase)
        }
        .padding(DSSpacing.m)
        .dsGlass(cornerRadius: DSRadius.holeCard)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: Self.accessibilityLabel(number: number, par: par, yards: yards, handicap: handicap)))
        .accessibilityIdentifier("hole.infoCard")
    }

    /// "Par 4" (shown in caps, DS-TY-03).
    public nonisolated static func parText(_ par: Int) -> String {
        String(localized: "Par \(par)", bundle: Bundle.maynardUI, comment: "Hole card: the hole's par, e.g. 'Par 4'. Shown in caps.")
    }

    /// "380 yds" (shown in caps).
    public nonisolated static func yardsText(_ yards: Int) -> String {
        String(localized: "\(yards) yds", bundle: Bundle.maynardUI,
               comment: "Hole card: the hole's length in yards, e.g. '380 yds'. Shown in caps.")
    }

    /// "Hcp 7": the hole's stroke index (shown in caps).
    public nonisolated static func handicapText(_ handicap: Int) -> String {
        String(localized: "Hcp \(handicap)", bundle: Bundle.maynardUI,
               comment: "Hole card: the hole's handicap (stroke index), abbreviated, e.g. 'Hcp 7'. Shown in caps.")
    }

    /// "Hole 1, par 4, 380 yards, handicap 7".
    public nonisolated static func accessibilityLabel(number: Int, par: Int, yards: Int, handicap: Int) -> String {
        String(localized: "Hole \(number), par \(par), \(yards) yards, handicap \(handicap)", bundle: Bundle.maynardUI,
               comment: "VoiceOver: the hole card, e.g. 'Hole 1, par 4, 380 yards, handicap 7'.")
    }
}
