//
//  PlayerProfileHeader.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI
import UIKit

/// The Player card's profile card (PC-HDR-01…03): a 72 pt avatar and the full name. No subtitle; the index is
/// in the Handicap Index row below the stat tiles (PC-HX-01, #253).
struct PlayerProfileHeader: View {
    let name: String
    let color: PlayerColor
    let photo: UIImage?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ContentCard(padding: DSSpacing.lx, spacing: DSSpacing.l) {
            HStack(spacing: DSSpacing.l) {
                PlayerAvatar(name: name, color: color.palette, photo: photo, size: .profile)
                    .accessibilityIdentifier("playerCard.avatar")
                // Two lines, then truncated (PC-HDR-03); unlimited at accessibility sizes.
                Text(verbatim: name)
                    .dsFont(.cardName)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("playerCard.name")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playerCard.profile")
    }
}

/// The Handicap Index row (PC-HX-01…03, #253): "Handicap Index", the index in Blue and a chevron, in a white
/// card. Tapping it opens the Handicap screen.
struct HandicapIndexRow: View {
    /// "8.4", "+2.1" or "—".
    let handicapText: String
    /// "Handicap index 8.4, calculated" (PC-HDR-05).
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ContentCard(padding: DSSpacing.l) {
                HStack(spacing: DSSpacing.sm) {
                    Text("Handicap Index", comment: "Player card: the row that opens the Handicap screen.")
                        .dsFont(.bodyEmphasized)
                        .foregroundStyle(Color.ds.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: handicapText)
                        .dsFont(.chipNumeral).dsNumeric()
                        .foregroundStyle(Color.ds.emphasis)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .dsFont(.label)
                        .foregroundStyle(Color.ds.textSecondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityLabel))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("playerCard.handicap")
    }
}

/// The three stat tiles (PC-ST-01…08): Avg score, Best and the 9 / 18 Holes toggle. At accessibility sizes
/// the tiles stack.
struct PlayerStatTiles: View {
    let average: String
    let best: String
    @Binding var holes: HoleCount
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: DSSpacing.s) { tiles }
        } else {
            HStack(alignment: .top, spacing: DSSpacing.s) { tiles }
        }
    }

    @ViewBuilder private var tiles: some View {
        StatTile(value: average, caption: Text(verbatim: PlayerSummaryCard.averageLabel))
            .accessibilityIdentifier("playerCard.stat.avg")
        StatTile(value: best, caption: Text(verbatim: PlayerSummaryCard.bestLabel))
            .accessibilityIdentifier("playerCard.stat.best")
        StatTile(caption: Text("Holes", comment: "Player card: caption under the 9 / 18 holes toggle.")) {
            DSSegmented(Text("Holes", comment: "Player card: caption under the 9 / 18 holes toggle."), selection: $holes,
                        options: HoleCount.allCases.map { count in
                            (count, Text(verbatim: "\(count.rawValue)")
                                .accessibilityLabel(Text("\(count.rawValue) holes",
                                                         comment: "Player card, VoiceOver: a value of the Holes toggle, e.g. '18 holes'.")))
                        },
                        compact: true, identifier: "playerCard.holes")
        }
    }
}

#if DEBUG
private struct TilesPreview: View {
    @State var holes: HoleCount

    var body: some View {
        PlayerStatTiles(average: holes == .nine ? "44.2" : "86.4", best: holes == .nine ? "39" : "79", holes: $holes)
            .padding(DSSpacing.gutter)
            .background(Color.ds.background)
    }
}

#Preview("Profile: initial") {
    PlayerProfileHeader(name: "Mark Tassinari", color: .lake, photo: nil)
        .padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Profile: long name") {
    PlayerProfileHeader(name: "José María Olazábal-Fernández de la Cruz", color: .sand, photo: nil)
        .padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Profile: photo, Dark, AX3") {
    PlayerProfileHeader(name: "Chris", color: .moss, photo: UIImage(systemName: "person.crop.circle.fill"))
        .padding(DSSpacing.gutter).background(Color.ds.background)
        .preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#Preview("Handicap Index row") {
    VStack(spacing: DSSpacing.m) {
        HandicapIndexRow(handicapText: "8.4", accessibilityLabel: "Handicap index 8.4, calculated") {}
        HandicapIndexRow(handicapText: "+2.1", accessibilityLabel: "Handicap index +2.1") {}
        HandicapIndexRow(handicapText: "—", accessibilityLabel: "No handicap index") {}
    }
    .padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Handicap Index row, Dark") {
    HandicapIndexRow(handicapText: "12.7", accessibilityLabel: "Handicap index 12.7") {}
        .padding(DSSpacing.gutter).background(Color.ds.background).preferredColorScheme(.dark)
}
#Preview("Stat tiles on 18") { TilesPreview(holes: .eighteen) }
#Preview("Stat tiles on 9") { TilesPreview(holes: .nine) }
#Preview("Stat tiles, no rounds") {
    PlayerStatTiles(average: "—", best: "—", holes: .constant(.eighteen)).padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Stat tiles, AX3") { TilesPreview(holes: .eighteen).dynamicTypeSize(.accessibility3) }
#endif
