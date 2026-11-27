import MaynardUI
import SwiftUI

/// None plus every player, with a single checked choice (SET-MQ-01…06). Selection commits before
/// navigation; Back never writes, and errors stay visible with the intended choice available to retry.
struct MarqueePlayerView: View {
    @State private var model: MarqueePlayerViewModel
    @Environment(Router.self) private var router

    init(model: MarqueePlayerViewModel) { _model = State(initialValue: model) }

    var body: some View {
        MarqueePlayerContent(model: model, select: select, retry: retry)
        .dsNavigationBar(Text("Marquee player", comment: "Settings option and player selection screen title.")) {
            Button(action: router.pop) {
                Label { Text("Settings", comment: "Settings screen title.") } icon: { Image(systemName: "chevron.left") }
            }
            .buttonStyle(.dsNeutralPill)
            .accessibilityIdentifier("marqueePlayer.back")
        }
        .task { await model.observe() }
    }

    private func select(_ id: UUID?) { if model.select(id) { router.pop() } }
    private func retry() { if model.retry() { router.pop() } }
}
