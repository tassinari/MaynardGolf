//
//  PlayerProfileHeader.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI
import UIKit

/// The Player card's profile card (PC-HDR-01…03, PC-ST-01…08): one card with the 112 pt avatar and the Avg score and
/// Best stats on top, the full name and the "9 holes" switch below, as the Player card — score graph artboard draws
/// it. The index is in the separate Handicap Index row (PC-HX-01). At accessibility sizes everything stacks.
struct PlayerProfileHeader: View {
    let name: String
    let color: PlayerColor
    let photo: UIImage?
    let average: String
    let best: String
    @Binding var holes: HoleCount
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ContentCard(padding: DSSpacing.lx, spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DSSpacing.l) {
                    avatar
                    nameText
                    stats
                    holesSwitch
                }
            } else {
                HStack(alignment: .top, spacing: DSSpacing.m) {
                    avatar
                    Spacer(minLength: 0)
                    stats
                }
                // The artboard tucks the name row 6 pt up into the avatar row.
                HStack(alignment: .bottom, spacing: DSSpacing.m) {
                    nameText
                    holesSwitch
                }
                .padding(.top, -DSSpacing.xs)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("playerCard.name")
    }

    /// Avg score | Best, split by a hairline (PC-ST-01…03).
    private var stats: some View {
        HStack(alignment: .top, spacing: 0) {
            PlayerCardStat(value: average, caption: PlayerSummaryCard.averageLabel)
                .padding(.horizontal, DSSpacing.l)
                .accessibilityIdentifier("playerCard.stat.avg")
            Rectangle().fill(Color.ds.divider).frame(width: 1).accessibilityHidden(true)
            PlayerCardStat(value: best, caption: PlayerSummaryCard.bestLabel)
                .padding(.leading, DSSpacing.l)
                .accessibilityIdentifier("playerCard.stat.best")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The "9 holes" switch (PC-ST-04): on shows 9-hole stats, off 18-hole.
    private var holesSwitch: some View {
        VStack(spacing: DSSpacing.xxs) {
            Toggle(isOn: Binding(get: { holes == .nine }, set: { holes = $0 ? .nine : .eighteen })) {
                Text("9 holes", comment: "Player card: the switch that shows 9-hole stats in place of 18-hole ones.")
            }
            .labelsHidden()
            .toggleStyle(.ds)
            .accessibilityIdentifier("playerCard.holes")
            Text("9 holes", comment: "Player card: the switch that shows 9-hole stats in place of 18-hole ones.")
                .dsFont(.caption)
                .foregroundStyle(Color.ds.textSecondary)
                .accessibilityHidden(true)
        }
        .fixedSize()
    }
}

/// One stat on the profile card (PC-ST-02, 03): a 28 pt bold `emphasis` value over a caption, centered, read as
/// "Avg score, 78.9".
struct PlayerCardStat: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: value).dsFont(.title).dsNumeric().foregroundStyle(Color.ds.emphasis).lineLimit(1)
            Text(verbatim: caption).dsFont(.caption).foregroundStyle(Color.ds.textSecondary).lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(caption), \(value)"))
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

#if DEBUG
private struct ProfilePreview: View {
    @State var holes: HoleCount

    var body: some View {
        PlayerProfileHeader(name: "Mark Tassinari", color: .lake, photo: nil,
                            average: holes == .nine ? "44.2" : "78.9", best: holes == .nine ? "39" : "74", holes: $holes)
            .padding(DSSpacing.gutter)
            .background(Color.ds.background)
    }
}

#Preview("Profile: initial") {
    PlayerProfileHeader(name: "Mark Tassinari", color: .lake, photo: nil,
                        average: "86.4", best: "79", holes: .constant(.eighteen))
        .padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Profile: long name") {
    PlayerProfileHeader(name: "José María Olazábal-Fernández de la Cruz", color: .sand, photo: nil,
                        average: "86.4", best: "79", holes: .constant(.eighteen))
        .padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Profile: photo, Dark, AX3") {
    PlayerProfileHeader(name: "Chris", color: .moss, photo: UIImage(systemName: "person.crop.circle.fill"),
                        average: "44.2", best: "39", holes: .constant(.nine))
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
#Preview("Profile on 18") { ProfilePreview(holes: .eighteen) }
#Preview("Profile on 9") { ProfilePreview(holes: .nine) }
#Preview("Profile, no rounds") {
    PlayerProfileHeader(name: "Mark Tassinari", color: .lake, photo: nil, average: "—", best: "—", holes: .constant(.eighteen))
        .padding(DSSpacing.gutter).background(Color.ds.background)
}
#Preview("Profile, Dark") { ProfilePreview(holes: .eighteen).preferredColorScheme(.dark) }
#endif
