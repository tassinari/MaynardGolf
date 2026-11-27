//
//  PlayerProfileHeader.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI
import UIKit

/// The Player card's profile card (PC-HDR-01…03, PC-ST-01): one card with the ringed 96 pt avatar on the left and,
/// in a column as tall as the avatar, Avg score | Best at the top and the full name at the bottom, both trailing, as
/// the Player card — score graph artboard draws it. The 9 / 18 control is on Latest Scores (PC-LS-01) and the index
/// in the separate Handicap Index row (PC-HX-01). At accessibility sizes the avatar, name and stats stack.
struct PlayerProfileHeader: View {
    let name: String
    let color: PlayerColor
    let photo: UIImage?
    let average: String
    let best: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ContentCard(padding: DSSpacing.lx, spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DSSpacing.l) {
                    avatar
                    nameText
                    stats
                }
            } else {
                HStack(alignment: .top, spacing: DSSpacing.l) {
                    avatar
                    VStack(alignment: .trailing, spacing: DSSpacing.xs) {
                        stats
                        Spacer(minLength: 0)
                        nameText
                    }
                    // The column spans the circle, inside the ring (PC-HDR-01); a two-line name may grow it.
                    .frame(maxWidth: .infinity, minHeight: AvatarSize.profile.rawValue, alignment: .trailing)
                    .padding(.vertical, PlayerAvatar.ringWidth)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playerCard.profile")
    }

    private var avatar: some View {
        PlayerAvatar(name: name, color: color.palette, photo: photo, size: .profile, ringed: true)
            .accessibilityIdentifier("playerCard.avatar")
    }

    /// Two lines, then truncated (PC-HDR-03); trailing beside the avatar, leading and unlimited at accessibility sizes.
    private var nameText: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        return Text(verbatim: name)
            .dsFont(.profileName)
            .foregroundStyle(Color.ds.textPrimary)
            .lineLimit(stacked ? nil : 2)
            .multilineTextAlignment(stacked ? .leading : .trailing)
            .frame(maxWidth: .infinity, alignment: stacked ? .leading : .trailing)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("playerCard.name")
    }

    /// Avg score | Best, split by a hairline (PC-ST-01…03).
    private var stats: some View {
        HStack(alignment: .top, spacing: 0) {
            PlayerCardStat(value: average, caption: PlayerSummaryCard.averageLabel)
                .padding(.trailing, DSSpacing.l)
                .accessibilityIdentifier("playerCard.stat.avg")
            Rectangle().fill(Color.ds.divider).frame(width: 1).accessibilityHidden(true)
            PlayerCardStat(value: best, caption: PlayerSummaryCard.bestLabel)
                .padding(.leading, DSSpacing.l)
                .accessibilityIdentifier("playerCard.stat.best")
        }
        .fixedSize(horizontal: false, vertical: true)
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
private func profile(_ name: String = "Mark Tassinari", color: PlayerColor = .lake, photo: UIImage? = nil,
                     average: String = "78.9", best: String = "74") -> some View {
    PlayerProfileHeader(name: name, color: color, photo: photo, average: average, best: best)
        .padding(DSSpacing.gutter)
        .background(Color.ds.background)
}

#Preview("Profile: initial") { profile() }
#Preview("Profile: photo") { profile(photo: UIImage(systemName: "person.crop.circle.fill")) }
#Preview("Profile: long name") { profile("José María Olazábal-Fernández de la Cruz", color: .sand, average: "86.4", best: "79") }
#Preview("Profile: 9 holes") { profile(color: .fairway, average: "44.2", best: "39") }
#Preview("Profile, no rounds") { profile(average: "—", best: "—") }
#Preview("Profile, Dark") { profile(color: .flag).preferredColorScheme(.dark) }
#Preview("Profile: photo, Dark") { profile(photo: UIImage(systemName: "person.crop.circle.fill")).preferredColorScheme(.dark) }
#Preview("Profile: AX3") {
    profile("Chris", color: .moss, photo: UIImage(systemName: "person.crop.circle.fill"), average: "44.2", best: "39")
        .dynamicTypeSize(.accessibility3)
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
#endif
