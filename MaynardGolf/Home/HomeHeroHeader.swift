//
//  HomeHeroHeader.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Home's photo hero (HOME-HDR-01…05): the course photo under a gradient, Settings and New round on glass,
/// and the app's name. It's 230 pt tall including the area under the status bar, and grows only when large
/// text needs the room.
struct HomeHeroHeader: View {
    /// The height of the area under the status bar, which the photo fills and the buttons stay below.
    let topInset: CGFloat
    let openSettings: () -> Void
    let startRound: () -> Void

    /// HOME-HDR-01's height.
    static let height: CGFloat = 230

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                GlassIconButton(Text("Settings", comment: "Home hero: the Settings button's accessibility label."),
                                systemImage: "gearshape.fill", action: openSettings)
                    .accessibilityIdentifier("home.settings")
                Spacer(minLength: DSSpacing.m)
                Button(action: startRound) {
                    Label { Text("New round", comment: "Home hero: the button that starts a new round.") } icon: { Image(systemName: "plus") }
                }
                .buttonStyle(.dsGlassPill)
                .accessibilityIdentifier("home.newRound")
            }
            Spacer(minLength: DSSpacing.xxxl)
            Text("Maynard Golf", comment: "Home hero title: the app's name (not the course name, X-16).")
                .dsFont(.titleXL)
                .foregroundStyle(Color.ds.chalk50)
                .dsGlassText()
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home.hero.title")
        }
        .padding(.horizontal, DSSpacing.gutter)
        .padding(.top, topInset + DSSpacing.xxs)
        .padding(.bottom, DSSpacing.lx)
        .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .topLeading)
        .background { photo }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.hero")
    }

    /// The photo, dimmed in Dark (DS-MT-05), under HOME-HDR-02's gradient.
    private var photo: some View {
        Image(HomeViewModel.heroImageName)
            .resizable()
            .scaledToFill()
            .dsPhotoDimming()
            .overlay {
                LinearGradient(stops: [
                    .init(color: Color.ds.canopy950.opacity(0.35), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .clear, location: 0.5),
                    .init(color: Color.ds.canopy950.opacity(0.75), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .accessibilityLabel(Text("Golf green with a white pin flag and autumn trees",
                                     comment: "Home hero photo's accessibility description."))
            .accessibilityAddTraits(.isImage)
    }
}

#if DEBUG
#Preview("Hero") {
    ScrollView {
        HomeHeroHeader(topInset: 59, openSettings: {}, startRound: {})
    }
    .ignoresSafeArea(edges: .top)
    .background(Color.ds.background)
}

#Preview("Hero, Dark, AX3") {
    ScrollView {
        HomeHeroHeader(topInset: 59, openSettings: {}, startRound: {})
    }
    .ignoresSafeArea(edges: .top)
    .background(Color.ds.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
#endif
