//
//  ComponentSamples.swift
//  MaynardUI
//

#if DEBUG
import PhotosUI
import CoreLocation
import SwiftUI

// Every state of each component group, shared by the catalog and the previews (00-design-system §7:
// previews of every state and variant). DEBUG only; labels are verbatim sample copy.

/// Buttons (DS-BT-01…09): every kind, enabled, disabled and loading, with and without icons.
struct ButtonSamples: View {
    @State private var loadingTaps = 0

    @ViewBuilder private var secondaryButtons: some View {
        Button {} label: { Text(verbatim: "Club up") }.buttonStyle(.dsTertiary)
        Button {} label: { Label { Text(verbatim: "Add player") } icon: { Image(systemName: "plus") } }
            .buttonStyle(.dsTinted)
    }

    @ViewBuilder private var pillButtons: some View {
        Button {} label: { Label { Text(verbatim: "Back") } icon: { Image(systemName: "chevron.left") } }
            .buttonStyle(.dsNeutralPill)
        Button {} label: { Text(verbatim: "See all") }.buttonStyle(.dsTextLink)
        Button {} label: { Text(verbatim: "Disabled") }.buttonStyle(.dsTextLink).disabled(true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            Button {} label: { Text(verbatim: "Tee off") }.buttonStyle(.dsPrimary(fullWidth: true))
                .accessibilityIdentifier("catalog.button.primary")
            Button {} label: { Text(verbatim: "Tee off") }.buttonStyle(.dsPrimary(height: .large, fullWidth: true)).disabled(true)
            ViewThatFits {
                HStack(spacing: DSSpacing.s) { secondaryButtons }
                VStack(alignment: .leading, spacing: DSSpacing.s) { secondaryButtons }
            }
            ViewThatFits {
                HStack(spacing: DSSpacing.s) { pillButtons }
                VStack(alignment: .leading, spacing: DSSpacing.s) { pillButtons }
            }
            // A loading button ignores taps: the count must stay at 0 (DS-BT-01).
            Button { loadingTaps += 1 } label: { Text(verbatim: "Saving") }
                .buttonStyle(.dsPrimary(isLoading: true))
                .accessibilityIdentifier("catalog.button.loading")
            Text(verbatim: "Loading taps: \(loadingTaps)")
                .dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                .accessibilityIdentifier("catalog.button.loadingTaps")
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
    @State private var selection: PhotosPickerItem?
    private static let names = ["Mark", "Scottie", "Tiger", "Phil", "José", "Chris", "Émile", "Nina"]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            HStack(spacing: DSSpacing.s) {
                // zip can't run past either list, so adding a size can't crash the catalog.
                ForEach(Array(zip(AvatarSize.allCases, zip(Self.names, PlayerPalette.allCases.cycled(8)))), id: \.0) { size, person in
                    PlayerAvatar(name: person.0, color: person.1, size: size)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("catalog.avatars")
            HStack(spacing: DSSpacing.m) {
                PlayerAvatar(name: "Photo", color: .lake, photo: SamplePhoto.image, size: .xl)
                HoleNumberBadge(number: 7)
                HoleNumberBadge(number: 18, size: .large)
                AvatarPicker(name: "Mark", color: .lake, photo: nil, selection: $selection)
                AvatarPicker(name: "Mark", color: .sand, photo: SamplePhoto.image, isLoading: true, selection: $selection)
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

/// Containers and rows (DS-CN-01…07, 13): cards, headers, player and round rows, tiles, the summary
/// card and an empty state, with short and long content.
struct ContainerSamples: View {
    private static let day = Date(timeIntervalSince1970: 1_780_326_000)

    /// A stable id per sample player (RoundRow scores need ids that don't change between renders).
    private static let ids: [String: UUID] = Dictionary(uniqueKeysWithValues: ["Mark", "Scottie", "Tiger", "Phil"].enumerated().map {
        ($0.element, UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0.offset + 1))))
    })

    private static func id(_ name: String) -> UUID { ids[name] ?? UUID() }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            SectionHeader(Text(verbatim: "Players"), count: (2, 4)) {
                Button {} label: { Label { Text(verbatim: "Add player") } icon: { Image(systemName: "plus") } }.buttonStyle(.dsTinted)
            }
            CardContainer {
                PlayerRow(name: "Mark Tassinari", color: .lake, subtitle: "Played 3 days ago", handicapIndex: 8.4, accessory: .chevron)
                DSDivider()
                PlayerRow(name: "Scottie", color: .sand, handicapIndex: -2.1, accessory: .checkbox(isOn: true))
                    .accessibilityIdentifier("catalog.playerRow.selected")
                DSDivider()
                PlayerRow(name: "José María Olazábal-Fernández", color: .moss, handicapIndex: nil, accessory: .checkbox(isOn: false))
            }
            SectionHeader(Text(verbatim: "Rounds")) { Button {} label: { Text(verbatim: "See all") }.buttonStyle(.dsTextLink) }
            CardContainer {
                RoundRow(date: Self.day, dateStyle: .month, courseName: "Maynard Golf Club", meta: "18 holes · Blue",
                         scores: [.init(id: Self.id("Mark"), name: "Mark", color: .lake, score: 81), .init(id: Self.id("Scottie"), name: "Scottie", color: .sand, score: 72),
                                  .init(id: Self.id("Tiger"), name: "Tiger", color: .flag, score: 75), .init(id: Self.id("Phil"), name: "Phil", color: .fairway, score: 78)])
                DSDivider()
                RoundRow(date: Self.day, dateStyle: .weekday, courseName: "Maynard Golf Club", meta: "9 holes · White",
                         scores: [.init(id: Self.id("Mark"), name: "Mark", color: .lake, score: 41)])
            }
            HStack(spacing: DSSpacing.s) {
                StatTile(value: "84.2", caption: Text(verbatim: "Avg score"))
                StatTile(value: "77", caption: Text(verbatim: "Best"))
            }
            PlayerSummaryCard(name: "Mark Tassinari", color: .lake, lastPlayed: Self.day, handicapIndex: 8.4,
                              average: "84", best: "77", lastRound: "81",
                              chart: (0..<12).map { .init(date: Self.day.addingTimeInterval(Double($0) * 2_592_000), index: 10 - Double($0) * 0.15) })
            EmptyStateView(Text(verbatim: "No rounds yet"), systemImage: "flag", message: Text(verbatim: "Your rounds show up here."))
                .frame(height: 220)
        }
    }
}

/// Form controls (DS-CN-08, 09, 10, 11, 12): settings rows, toggle, segmented, fields, selectable cards.
struct FormSamples: View {
    @State private var haptics = true
    @State private var unit = DistanceUnit.yards
    @State private var holes = 9
    @State private var first = ""
    @State private var color = PlayerPalette.sand
    @State private var last = "Tassinari"
    @State private var tee = "White"

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            CardContainer {
                SettingsRow(Text(verbatim: "Haptics"), hint: Text(verbatim: "Taps when a score is saved")) {
                    Toggle(isOn: $haptics) { Text(verbatim: "Haptics") }.labelsHidden().toggleStyle(.ds)
                        .accessibilityIdentifier("catalog.toggle")
                }
                DSDivider()
                SettingsRow(Text(verbatim: "Distances")) {
                    DSSegmented(Text(verbatim: "Distances"), selection: $unit,
                                options: [(.yards, Text(verbatim: "Yards")), (.meters, Text(verbatim: "Meters"))],
                                identifier: "catalog.segmented")
                        .frame(width: 180)
                }
            }
            Text(verbatim: "Unit: \(unit.rawValue)").dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                .accessibilityIdentifier("catalog.segmented.value")
            StatTile(caption: Text(verbatim: "Holes")) {
                DSSegmented(Text(verbatim: "Holes"), selection: $holes,
                            options: [(9, Text(verbatim: "9")), (18, Text(verbatim: "18"))], compact: true)
            }
            FormFieldCard(fields: [
                .init(id: "catalog.field.first", label: Text(verbatim: "First name"), placeholder: "Required", text: $first,
                      contentType: .givenName, capitalization: .words),
                .init(id: "catalog.field.last", label: Text(verbatim: "Last name"), placeholder: "Optional", text: $last,
                      contentType: .familyName, capitalization: .words),
            ])
            FormFieldCard(fields: [
                .init(id: "catalog.field.index", label: Text(verbatim: "Handicap index"), placeholder: "e.g. 8.4",
                      text: .constant("60"), keyboard: .decimalPad,
                      error: Text(verbatim: "Enter a number from +10.0 to 54.0")),
            ])
            CardContainer(radius: DSRadius.card) {
                ColorSwatchPicker(selection: $color, identifierPrefix: "catalog.color").padding(.vertical, DSSpacing.s)
            }
            HStack(spacing: DSSpacing.s) {
                ForEach(["White", "Blue"], id: \.self) { name in
                    Button { tee = name } label: {
                        SelectableCard(isSelected: tee == name) {
                            Text(verbatim: name).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Navigation and sheets (DS-NV-01…04): the bar, both sheets and the sticky button.
struct NavigationSamples: View {
    @State private var showGlass = false
    @State private var showLight = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            DSNavigationBar(Text(verbatim: "New round")) {
                Button {} label: { Text(verbatim: "Cancel") }.buttonStyle(.dsNeutralPill)
            } trailing: {
                EmptyView()
            }
            NavigationLink { PushedSample() } label: { Text(verbatim: "Push a screen") }
                .buttonStyle(.dsTinted)
                .accessibilityIdentifier("catalog.push")
            HStack(spacing: DSSpacing.s) {
                Button { showGlass = true } label: { Text(verbatim: "Glass sheet") }.buttonStyle(.dsTinted)
                    .accessibilityIdentifier("catalog.openGlassSheet")
                Button { showLight = true } label: { Text(verbatim: "Light sheet") }.buttonStyle(.dsTinted)
                    .accessibilityIdentifier("catalog.openLightSheet")
            }
            Color.ds.surfaceCard
                .frame(height: 140)
                .overlay(Text(verbatim: "Content scrolls under the button").dsFont(.caption).foregroundStyle(Color.ds.textSecondary))
                .dsStickyBottomCTA {
                    Button {} label: { Text(verbatim: "Tee off") }.buttonStyle(.dsPrimary(fullWidth: true))
                }
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
        }
        .dsGlassSheet(isPresented: $showGlass) {
            Text(verbatim: "Enter score").dsFont(.title).foregroundStyle(Color.ds.chalk50).dsGlassText()
                .padding().accessibilityIdentifier("catalog.glassSheet")
        }
        .sheet(isPresented: $showLight) {
            LightSheet(Text(verbatim: "Local rules"), subtitle: Text(verbatim: "Maynard Golf Club"),
                       closeLabel: Text(verbatim: "Close"), onClose: { showLight = false }) {
                Text(verbatim: "Rules go here.").padding().foregroundStyle(Color.ds.textPrimary)
                    .accessibilityIdentifier("catalog.lightSheet")
            }
            .dsLightSheet()
        }
    }
}

/// A pushed screen with the custom bar, to check back navigation (including the edge swipe) still works.
struct PushedSample: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Text(verbatim: "Pushed").dsFont(.title).foregroundStyle(Color.ds.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ds.background)
            .accessibilityIdentifier("catalog.pushed")
            .dsNavigationBar(Text(verbatim: "Pushed")) {
                Button { dismiss() } label: { Label { Text(verbatim: "Back") } icon: { Image(systemName: "chevron.left") } }
                    .buttonStyle(.dsNeutralPill)
                    .accessibilityIdentifier("catalog.pushed.back")
            }
    }
}

/// Golf display (DS-GF-01…07): the full score-mark matrix (par 3/4/5 × every score, plus not played),
/// the legend, to-par text on both surfaces, every score name, weather, tees and the hole card.
struct GolfSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            Grid(horizontalSpacing: DSSpacing.xxs, verticalSpacing: DSSpacing.xs) {
                ForEach([3, 4, 5], id: \.self) { par in
                    GridRow {
                        Text(verbatim: "Par \(par)").dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                        ForEach(1...8, id: \.self) { score in ScoreMark(score: score, par: par) }
                        ScoreMark(score: nil, par: par)
                    }
                }
            }
            .padding(DSSpacing.s)
            .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.ds.surfaceCard))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("catalog.golf.marks")
            ScoreLegend()
            HStack(spacing: DSSpacing.m) {
                ForEach([-3, 0, 4], id: \.self) { ToParText(value: $0) }
                ToParText(value: 2, surface: .app(emphasized: true))
            }
            ZStack {
                AerialSample()
                HStack(spacing: DSSpacing.m) {
                    ForEach([-1, 0, 2], id: \.self) { ToParText(value: $0, surface: .imagery, style: .title) }
                }
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
            FlowLayout(spacing: DSSpacing.xs) {
                ForEach(ScoreFormatter.ScoreName.allCases, id: \.self) { ScoreNameBadge($0) }
            }
            FlowLayout(spacing: DSSpacing.m) {
                ForEach(WeatherIcon.Kind.allCases, id: \.self) { WeatherIcon($0, temperature: 62) }
                WeatherIcon(.cloudy)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("catalog.golf.weather")
            HStack(spacing: DSSpacing.m) {
                ForEach(TeeDot.Tee.allCases, id: \.self) { tee in
                    HStack(spacing: DSSpacing.xs) {
                        TeeDot(tee)
                        Text(verbatim: tee.rawValue.capitalized).dsFont(.body).foregroundStyle(Color.ds.textPrimary)
                    }
                }
            }
            ZStack(alignment: .trailing) {
                AerialSample()
                HoleInfoCard(number: 1, par: 4, yards: 380, handicap: 7).padding(DSSpacing.s)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
        }
    }
}

/// A fixed projection for the overlay samples: course coordinates are read as points (x = longitude,
/// y = latitude), so the samples need no map.
struct SampleProjection: OverlayProjection {
    func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
        CGPoint(x: coordinate.longitude, y: coordinate.latitude)
    }
}

/// Course overlays (DS-OV-01, 02, 09, 10) over the sample aerial: tee → target → pin with the yardage
/// panel under the target.
struct OverlaySamples: View {
    private let projection = SampleProjection()
    private let tee = CLLocationCoordinate2D(latitude: 250, longitude: 60)
    private let target = CLLocationCoordinate2D(latitude: 130, longitude: 170)
    private let pin = CLLocationCoordinate2D(latitude: 40, longitude: 280)
    @State private var yards = 165

    var body: some View {
        ZStack {
            AerialSample()
            ShotLine(coordinates: [tee, target, pin], projection: projection)
            PinMarker().overlayPosition(pin, in: projection)
            TargetMarker(yards: yards, toPin: 380 - yards) { step in
                yards += step == .towardPin ? 10 : -10
            }
            .overlayPosition(target, in: projection)
            YardagePanel(toTarget: Double(yards), toPin: Double(380 - yards))
                .fixedSize()
                .position(x: target.longitude, y: target.latitude + 30 + 36)
        }
        .frame(width: 320, height: 290)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
        .accessibilityElement(children: .contain)
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

extension Array {
    /// The array repeated until it has `count` elements.
    func cycled(_ count: Int) -> [Element] {
        isEmpty ? [] : (0..<count).map { self[$0 % self.count] }
    }
}

#Preview("Buttons") { ScrollView { ButtonSamples().padding() }.background(Color.ds.background) }
#Preview("Buttons, Dark") { ScrollView { ButtonSamples().padding() }.background(Color.ds.background).preferredColorScheme(.dark) }
#Preview("Buttons, AX3") { ScrollView { ButtonSamples().padding() }.background(Color.ds.background).dynamicTypeSize(.accessibility3) }
#Preview("Identity") { IdentitySamples().padding().background(Color.ds.background) }
#Preview("Identity, Dark") { IdentitySamples().padding().background(Color.ds.background).preferredColorScheme(.dark) }
#Preview("Chips") { ChipSamples().padding().background(Color.ds.background) }
#Preview("Containers") { ScrollView { ContainerSamples().padding() }.background(Color.ds.background) }
#Preview("Containers, Dark, AX3") {
    ScrollView { ContainerSamples().padding() }.background(Color.ds.background).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#Preview("Forms") { ScrollView { FormSamples().padding() }.background(Color.ds.background) }
#Preview("Forms, Dark") { ScrollView { FormSamples().padding() }.background(Color.ds.background).preferredColorScheme(.dark) }
#Preview("Navigation") { NavigationSamples().padding().background(Color.ds.background) }
#Preview("Navigation, Dark, AX3") {
    NavigationSamples().padding().background(Color.ds.background).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#Preview("Golf display") { ScrollView { GolfSamples().padding() }.background(Color.ds.background) }
#Preview("Golf display, Dark") { ScrollView { GolfSamples().padding() }.background(Color.ds.background).preferredColorScheme(.dark) }
#Preview("Golf display, AX3") { ScrollView { GolfSamples().padding() }.background(Color.ds.background).dynamicTypeSize(.accessibility3) }
#Preview("Course overlays") { OverlaySamples().padding().background(Color.ds.background) }
#Preview("Course overlays, Dark, AX3") {
    OverlaySamples().padding().background(Color.ds.background).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#Preview("Chips, Dark, AX3") {
    ChipSamples().padding().background(Color.ds.background).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#endif
