//
//  ComponentSamples.swift
//  MaynardUI
//

#if DEBUG
import PhotosUI
import SwiftUI

// Every state of each component group, shared by the catalog and the previews (00-design-system §7:
// previews of every state and variant). DEBUG only; labels are verbatim sample copy.

/// Buttons (DS-BT-01…09): every kind, enabled, disabled and loading, with and without icons.
struct ButtonSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            Button {} label: { Text(verbatim: "Tee off") }.buttonStyle(.dsPrimary(fullWidth: true))
                .accessibilityIdentifier("catalog.button.primary")
            Button {} label: { Text(verbatim: "Tee off") }.buttonStyle(.dsPrimary(height: .large, fullWidth: true)).disabled(true)
            Button {} label: { Text(verbatim: "Saving") }.buttonStyle(.dsPrimary(isLoading: true))
            HStack(spacing: DSSpacing.s) {
                Button {} label: { Text(verbatim: "Club up") }.buttonStyle(.dsTertiary)
                Button {} label: { Label { Text(verbatim: "Add player") } icon: { Image(systemName: "plus") } }
                    .buttonStyle(.dsTinted)
            }
            HStack(spacing: DSSpacing.s) {
                Button {} label: { Label { Text(verbatim: "Back") } icon: { Image(systemName: "chevron.left") } }
                    .buttonStyle(.dsNeutralPill)
                Button {} label: { Text(verbatim: "See all") }.buttonStyle(.dsTextLink)
                Button {} label: { Text(verbatim: "Disabled") }.buttonStyle(.dsTextLink).disabled(true)
            }
            CircleIconButton(Text(verbatim: "Close")) {}
            ZStack {
                AerialSample().dsPhotoDimming()
                HStack(spacing: DSSpacing.s) {
                    Button {} label: { Text(verbatim: "View card") }.buttonStyle(.dsScrim)
                    Button {} label: { Label { Text(verbatim: "Exit") } icon: { Image(systemName: "xmark") } }
                        .buttonStyle(.dsGlassPill)
                    GlassIconButton(Text(verbatim: "Settings"), systemImage: "gearshape") {}
                    GlassIconButton(Text(verbatim: "Course map"), systemImage: "map", size: .large) {}
                    CircleIconButton(Text(verbatim: "Close"), onGlass: true) {}
                }
                .padding(DSSpacing.s)
            }
            .frame(height: 96)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
        }
    }
}

/// Identity (DS-ID-01…03): every avatar size, photo and initial, badges and the picker.
struct IdentitySamples: View {
    @State private var selection: PhotosPickerItemBox = .init()

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            HStack(spacing: DSSpacing.s) {
                ForEach(Array(AvatarSize.allCases.enumerated()), id: \.offset) { index, size in
                    PlayerAvatar(name: ["Mark", "Scottie", "Tiger", "Phil", "José", "Chris", "Émile"][index],
                                 color: PlayerPalette.allCases[index % PlayerPalette.allCases.count], size: size)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("catalog.avatars")
            HStack(spacing: DSSpacing.m) {
                PlayerAvatar(name: "Photo", color: .lake, photo: SamplePhoto.image, size: .xl)
                HoleNumberBadge(number: 7)
                HoleNumberBadge(number: 18, size: .large)
                AvatarPicker(name: "Mark", color: .lake, photo: nil, selection: $selection.item)
                AvatarPicker(name: "Mark", color: .sand, photo: SamplePhoto.image, isLoading: true, selection: $selection.item)
            }
        }
    }
}

/// Chips (DS-CH-01…08): every chip, yards and meters, short and long labels.
struct ChipSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            ZStack(alignment: .leading) {
                AerialSample()
                HStack(spacing: DSSpacing.s) {
                    YardageChip(yards: 148)
                    YardageChip(yards: 148, unit: .meters)
                    PinChip(yards: 162)
                }
                .padding(DSSpacing.s)
            }
            .frame(height: 64)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("catalog.chips.overlay")
            HStack(spacing: DSSpacing.s) {
                HazardChip(Text(verbatim: "Bunker · 245 carry"))
                StatusPill(.inProgress)
            }
            HStack(spacing: DSSpacing.s) {
                NumberChip(1)
                NumberChip(12)
                PlayerScoreChip(name: "Mark", color: .lake, score: 41)
                PlayerScoreChip(name: "Scottie", color: .sand, photo: SamplePhoto.image, score: 38)
            }
        }
    }
}

/// A drawn stand-in photo for previews (no image files in the framework).
enum SamplePhoto {
    @MainActor static let image: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120))
        return renderer.image { context in
            DSColorToken.fairway500.uiColor().setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
            DSColorToken.bunker300.uiColor().setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 30, y: 20, width: 60, height: 60))
        }
    }()
}

/// Holds the picker selection for the samples.
struct PhotosPickerItemBox {
    var item: PhotosPickerItem?
}

#Preview("Buttons") { ScrollView { ButtonSamples().padding() }.background(Color.ds.background) }
#Preview("Buttons, Dark") { ScrollView { ButtonSamples().padding() }.background(Color.ds.background).preferredColorScheme(.dark) }
#Preview("Buttons, AX3") { ScrollView { ButtonSamples().padding() }.background(Color.ds.background).dynamicTypeSize(.accessibility3) }
#Preview("Identity") { IdentitySamples().padding().background(Color.ds.background) }
#Preview("Identity, Dark") { IdentitySamples().padding().background(Color.ds.background).preferredColorScheme(.dark) }
#Preview("Chips") { ChipSamples().padding().background(Color.ds.background) }
#Preview("Chips, Dark, AX3") {
    ChipSamples().padding().background(Color.ds.background).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#endif
