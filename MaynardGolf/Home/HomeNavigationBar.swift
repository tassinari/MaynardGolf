import MaynardUI
import SwiftUI

/// Home's pinned actions (HOME-HDR-03…05, #212). The bar is transparent over the single scrolling
/// hero, then adds Apple’s untinted ultra-thin material (#232). A single New round button keeps its action and identity as it shrinks.
struct HomeNavigationBar: View {
    let isScrolled: Bool
    let openSettings: () -> Void
    let startRound: () -> Void

    var body: some View {
        DSNavigationBar(Text("Maynard Golf", comment: "Home hero title: the app's name (not the course name, X-16)."),
                        background: .systemMaterial(isScrolled: isScrolled), showsTitle: isScrolled,
                        titleStyle: .body, titleColor: Color.ds.black) {
            GlassIconButton(Text("Settings", comment: "Home hero: the Settings button's accessibility label."),
                            systemImage: "gearshape.fill", action: openSettings)
                .accessibilityIdentifier("home.settings")
        } trailing: {
            Button(action: startRound) {
                HStack(spacing: DSSpacing.s) {
                    Image(systemName: "plus")
                    if !isScrolled {
                        Text("New round", comment: "Home hero: the button that starts a new round.")
                            .accessibilityIdentifier("home.newRound.title")
                            .transition(.opacity)
                    }
                }
            }
            .buttonStyle(.dsGlassPill)
            .accessibilityLabel(Text("New round", comment: "Home hero: the button that starts a new round."))
            .accessibilityIdentifier("home.newRound")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.navigationBar")
        .animation(.easeInOut(duration: 0.2), value: isScrolled)
    }
}

#if DEBUG
#Preview("Expanded") {
    HomeNavigationBar(isScrolled: false, openSettings: {}, startRound: {})
}
#Preview("Compact") {
    HomeNavigationBar(isScrolled: true, openSettings: {}, startRound: {})
}
#Preview("Expanded, Dark") {
    HomeNavigationBar(isScrolled: false, openSettings: {}, startRound: {}).preferredColorScheme(.dark)
}
#Preview("Compact, Dark") {
    HomeNavigationBar(isScrolled: true, openSettings: {}, startRound: {}).preferredColorScheme(.dark)
}
#endif
