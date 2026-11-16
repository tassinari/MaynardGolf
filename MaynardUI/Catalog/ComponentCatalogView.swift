//
//  ComponentCatalogView.swift
//  MaynardUI
//

#if DEBUG
import SwiftUI

/// The design-system catalog (#2, DS-BR-02): every token, type style, material and, as they land, every
/// component, in Light and Dark. DEBUG only; the app opens it with `-uiTestCatalog`. It's a developer
/// tool, so its labels are verbatim (token names and sample copy), not String Catalog entries.
public struct ComponentCatalogView: View {
    /// The component groups of 00-design-system §7, in catalog order. Each gets a section; groups not
    /// built yet show a placeholder.
    public static let groups = ["Buttons", "Identity", "Chips & badges", "Containers & rows", "Form controls",
                                "Navigation & sheets", "Golf display", "Course overlay"]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.dsReduceTransparencyOverride) private var reduceTransparencyOverride

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                header
                Section { materials } header: { sectionHeader("Materials") }
                Section { typeRows } header: { sectionHeader("Type") }
                Section { playerColors } header: { sectionHeader("Player colors") }
                ForEach(Self.groups, id: \.self) { group in
                    Section {
                        samples(for: group)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("catalog.group.\(group)")
                    } header: { sectionHeader(group) }
                }
                Section { colorRows(DSColorToken.semantic) } header: { sectionHeader("Semantic colors") }
                Section { colorRows(DSColorToken.primitives) } header: { sectionHeader("Primitives") }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ds.background)
            .navigationTitle(Text(verbatim: "Fairway Overlay"))
        }
        .accessibilityIdentifier("catalog.root")
    }

    /// The samples for a component group, or a placeholder until its story builds it.
    @ViewBuilder
    private func samples(for group: String) -> some View {
        switch group {
        case "Buttons": ButtonSamples()
        case "Identity": IdentitySamples()
        case "Chips & badges": ChipSamples()
        default: Text(verbatim: "Coming with its story").foregroundStyle(Color.ds.textSecondary)
        }
    }

    /// Section titles in a token color (the List default grey falls short of contrast on Chalk).
    private func sectionHeader(_ title: String) -> some View {
        Text(verbatim: title).dsFont(.label).foregroundStyle(Color.ds.textSecondary)
    }

    private var scrimSpec: MaterialSpec {
        MaterialSpec.resolve(colorScheme: colorScheme, reduceTransparency: reduceTransparencyOverride ?? systemReduceTransparency)
    }

    private var header: some View {
        Text(verbatim: "Design system · v1")
            .dsFont(.caption)
            .textCase(.uppercase) // no tracking: the audit reads tracked trailing space as clipping
            .foregroundStyle(Color.ds.textSecondary)
            .accessibilityIdentifier("catalog.header")
    }

    private func colorRows(_ tokens: [DSColorToken]) -> some View {
        ForEach(tokens, id: \.self) { token in
            HStack(spacing: DSSpacing.m) {
                RoundedRectangle(cornerRadius: DSRadius.chip)
                    .fill(Color(token))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.chip).strokeBorder(Color.ds.cardBorder))
                    .frame(width: 44, height: 32)
                    .accessibilityHidden(true)
                Text(verbatim: token.rawValue).dsFont(.body).foregroundStyle(Color.ds.textPrimary)
            }
        }
    }

    private var playerColors: some View {
        HStack(spacing: DSSpacing.m) {
            ForEach(PlayerPalette.allCases, id: \.self) { color in
                Text(verbatim: String(color.rawValue.prefix(1)).uppercased())
                    .dsFont(.bodyEmphasized)
                    .foregroundStyle(color.foreground)
                    .frame(width: 40, height: 40)
                    .background(color.background, in: Circle())
                    .accessibilityLabel(Text(verbatim: color.rawValue))
            }
        }
    }

    private var typeRows: some View {
        ForEach(DSTextStyle.allCases, id: \.self) { style in
            Text(verbatim: style == .numeral ? "148 · 162 · 175" : style.rawValue)
                .dsFont(style)
                .foregroundStyle(Color.ds.textPrimary)
                .fixedSize(horizontal: false, vertical: true) // wraps at every size, never truncates
                .accessibilityIdentifier("catalog.type.\(style.rawValue)")
        }
    }

    private var materials: some View {
        ZStack {
            AerialSample().dsPhotoDimming()
            VStack(spacing: DSSpacing.m) {
                Text(verbatim: "Glass").dsFont(.bodyEmphasized).foregroundStyle(Color.ds.chalk50).dsGlassText()
                    .padding(DSSpacing.m).dsGlass().accessibilityIdentifier("catalog.glass")
                Text(verbatim: "Scrim").dsFont(.bodyEmphasized).foregroundStyle(Color.ds.chalk50)
                    .padding(DSSpacing.m).dsScrim().accessibilityIdentifier("catalog.scrim")
                    // Lets UI tests see which scrim Reduce Transparency produced.
                    .accessibilityValue(Text(verbatim: scrimSpec.scrimBlurs ? "blur" : "opaque"))
            }
        }
        .frame(height: 220)
        .listRowInsets(EdgeInsets())
    }
}

/// Mowing stripes in the course greens, standing in for an aerial photo behind the material samples.
struct AerialSample: View {
    var body: some View {
        Canvas { context, size in
            let stripes = [Color.ds.fairway500, Color.ds.rough600]
            let width = size.width / 8
            for index in 0..<8 {
                context.fill(Path(CGRect(x: CGFloat(index) * width, y: 0, width: width, height: size.height)),
                             with: .color(stripes[index % 2]))
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Catalog") {
    ComponentCatalogView()
}

#Preview("Catalog, Dark") {
    ComponentCatalogView().preferredColorScheme(.dark)
}

#Preview("Catalog, AX3") {
    ComponentCatalogView().dynamicTypeSize(.accessibility3)
}

#Preview("Catalog, Reduce Transparency") {
    ComponentCatalogView().environment(\.dsReduceTransparencyOverride, true)
}
#endif
