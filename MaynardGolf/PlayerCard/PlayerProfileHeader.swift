//
//  PlayerProfileHeader.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI
import UIKit

/// The Player card's profile card (PC-HDR-01…05): one card with the ringed 96 pt avatar on the left and, in a
/// column as tall as the avatar, the handicap index ("HCP INDEX" over the value) at the top and the full name at the
/// bottom, both trailing, as the Player card — score graph artboard draws it. A tap anywhere on the card opens the
/// Handicap screen (PC-HDR-06); the index itself is the card's button for VoiceOver and UI tests. Avg and Best are
/// under Latest Scores (PC-ST-01). At accessibility sizes the avatar, index and name stack.
struct PlayerProfileHeader: View {
    let name: String
    let color: PlayerColor
    let photo: UIImage?
    /// "8.4", "+2.1" or "—" (PC-HDR-04, 05).
    let handicapText: String
    /// "Handicap index 8.4, calculated" (PC-HDR-05).
    let handicapAccessibilityLabel: String
    /// Opens the Handicap screen (PC-HDR-06).
    let openHandicap: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ContentCard(padding: DSSpacing.lx, spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DSSpacing.l) {
                    avatar
                    index
                    nameText
                }
            } else {
                HStack(alignment: .top, spacing: DSSpacing.l) {
                    avatar
                    VStack(alignment: .trailing, spacing: DSSpacing.xs) {
                        index
                        Spacer(minLength: 0)
                        nameText
                    }
                    // The column spans the circle, inside the ring (PC-HDR-01); a two-line name may grow it.
                    .frame(maxWidth: .infinity, minHeight: AvatarSize.profile.rawValue, alignment: .trailing)
                    .padding(.vertical, PlayerAvatar.ringWidth)
                }
            }
        }
        // The whole card is the tap target (PC-HDR-06); the index button below is its accessible form.
        .contentShape(.rect(cornerRadius: DSRadius.summaryCard))
        .onTapGesture(perform: openHandicap)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playerCard.profile")
    }

    private var avatar: some View {
        PlayerAvatar(name: name, color: color.palette, photo: photo, size: .profile, ringed: true)
            .accessibilityIdentifier("playerCard.avatar")
    }

    /// "HCP INDEX" over the index in Blue (PC-HDR-04), centered on each other; a button to the Handicap screen.
    private var index: some View {
        Button(action: openHandicap) {
            VStack(spacing: 1) {
                Text(verbatim: PlayerSummaryCard.indexLabel)
                    .dsFont(.labelSmall).textCase(.uppercase)
                    .foregroundStyle(Color.ds.textSecondary)
                Text(verbatim: handicapText)
                    .dsFont(.numeral).dsNumeric()
                    .foregroundStyle(Color.ds.emphasis)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: handicapAccessibilityLabel))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("playerCard.handicap")
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
}

#if DEBUG
private func profile(_ name: String = "Mark Tassinari", color: PlayerColor = .lake, photo: UIImage? = nil,
                     handicap: String = "10.1", label: String = "Handicap index 10.1, calculated") -> some View {
    PlayerProfileHeader(name: name, color: color, photo: photo, handicapText: handicap, handicapAccessibilityLabel: label) {}
        .padding(DSSpacing.gutter)
        .background(Color.ds.background)
}

#Preview("Profile: initial") { profile() }
#Preview("Profile: photo") { profile(photo: UIImage(systemName: "person.crop.circle.fill")) }
#Preview("Profile: long name") { profile("José María Olazábal-Fernández de la Cruz", color: .sand, handicap: "24.6") }
#Preview("Profile: plus index") { profile(color: .fairway, handicap: "+2.1", label: "Handicap index +2.1") }
#Preview("Profile, no index") { profile(handicap: "—", label: "No handicap index") }
#Preview("Profile, Dark") { profile(color: .flag).preferredColorScheme(.dark) }
#Preview("Profile: photo, Dark") { profile(photo: UIImage(systemName: "person.crop.circle.fill")).preferredColorScheme(.dark) }
#Preview("Profile: AX3") {
    profile("Chris", color: .moss, photo: UIImage(systemName: "person.crop.circle.fill"))
        .dynamicTypeSize(.accessibility3)
}
#endif
