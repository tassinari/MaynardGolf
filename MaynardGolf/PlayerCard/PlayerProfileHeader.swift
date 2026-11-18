//
//  PlayerProfileHeader.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI
import UIKit

/// The Player card's profile card (PC-HDR-01…05): a 72 pt avatar, the full name and the HCP INDEX block.
/// No subtitle and no trend. At accessibility sizes the index moves under the name, so nothing truncates.
struct PlayerProfileHeader: View {
    let name: String
    let color: PlayerColor
    let photo: UIImage?
    /// "8.4", "+2.1" or "—".
    let handicapText: String
    /// "Handicap index 8.4, calculated" (PC-HDR-05).
    let handicapAccessibilityLabel: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ContentCard(padding: DSSpacing.lx, spacing: DSSpacing.l) {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: DSSpacing.l) { avatar; nameText }
                index(alignment: .leading)
            } else {
                HStack(spacing: DSSpacing.l) {
                    avatar
                    nameText
                    Spacer(minLength: DSSpacing.s)
                    index(alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playerCard.profile")
    }

    private var avatar: some View {
        PlayerAvatar(name: name, color: color.palette, photo: photo, size: .profile)
            .accessibilityIdentifier("playerCard.avatar")
    }

    /// Two lines, then truncated (PC-HDR-03); unlimited at accessibility sizes.
    private var nameText: some View {
        Text(verbatim: name)
            .dsFont(.cardName)
            .foregroundStyle(Color.ds.textPrimary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("playerCard.name")
    }

    /// "HCP INDEX" over the index in Lake (PC-HDR-04), read as one element (PC-HDR-05).
    private func index(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(verbatim: PlayerSummaryCard.indexLabel)
                .dsFont(.labelSmall)
                .textCase(.uppercase)
                .foregroundStyle(Color.ds.textSecondary) // semantic, so it follows Dark (as on Home's summary card)
            Text(verbatim: handicapText)
                .dsFont(.titleXL)
                .dsNumeric()
                .foregroundStyle(Color.ds.primaryAction)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: handicapAccessibilityLabel))
        .accessibilityIdentifier("playerCard.hcp")
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

#Preview("Profile: calculated index, initial") {
    PlayerProfileHeader(name: "Mark Tassinari", color: .lake, photo: nil, handicapText: "8.4",
                        handicapAccessibilityLabel: "Handicap index 8.4, calculated")
        .padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Profile: plus index, long name") {
    PlayerProfileHeader(name: "José María Olazábal-Fernández de la Cruz", color: .sand, photo: nil, handicapText: "+2.1",
                        handicapAccessibilityLabel: "Handicap index +2.1")
        .padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Profile: no index, photo") {
    PlayerProfileHeader(name: "Chris", color: .moss, photo: UIImage(systemName: "person.crop.circle.fill"), handicapText: "—",
                        handicapAccessibilityLabel: "No handicap index")
        .padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Profile, Dark, AX3") {
    PlayerProfileHeader(name: "Mark Tassinari", color: .lake, photo: nil, handicapText: "12.7",
                        handicapAccessibilityLabel: "Handicap index 12.7")
        .padding(DSSpacing.gutter).background(Color.ds.background)
        .preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#Preview("Stat tiles on 18") { TilesPreview(holes: .eighteen) }
#Preview("Stat tiles on 9") { TilesPreview(holes: .nine) }
#Preview("Stat tiles, no rounds") {
    PlayerStatTiles(average: "—", best: "—", holes: .constant(.eighteen)).padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Stat tiles, AX3") { TilesPreview(holes: .eighteen).dynamicTypeSize(.accessibility3) }
#endif
