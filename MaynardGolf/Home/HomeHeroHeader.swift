//
//  HomeHeroHeader.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Home's scrolling photo and expanded title (HOME-HDR-01…06). The actions live in the pinned
/// HomeNavigationBar (#212); hiding the title keeps the hero's height stable during scrolling.
struct HomeHeroHeader: View {
    var showsTitle = true
    /// Extra photo height above the hero while the scroll view rubber-bands past its top.
    var pullDown: CGFloat = 0

    /// HOME-HDR-01's height, including the image under the status and navigation bars.
    static let height: CGFloat = 230

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsTitle {
                Text("Maynard Golf", comment: "Home hero title: the app's name (not the course name, X-16).")
                    .dsFont(.titleXL)
                    .foregroundStyle(Color.ds.chalk50)
                    .dsGlassText()
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("home.hero.title")
            }
        }
        .padding(.horizontal, DSSpacing.gutter)
        .padding(.bottom, DSSpacing.lx)
        .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .bottomLeading)
        .background(alignment: .bottom) {
            Self.photo
                .frame(height: Self.height + pullDown)
                .clipped()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.hero")
    }

    /// The photo, dimmed in Dark (DS-MT-05), under HOME-HDR-02's gradient.
    static var photo: some View {
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
        HomeHeroHeader()
    }
    .ignoresSafeArea(edges: .top)
    .background(Color.ds.background)
}

#Preview("Pulled down") {
    HomeHeroHeader(pullDown: 100)
        .padding(.top, 100)
        .background(Color.ds.background)
}

#Preview("Hero, Dark, AX3") {
    ScrollView {
        HomeHeroHeader()
    }
    .ignoresSafeArea(edges: .top)
    .background(Color.ds.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
#endif
