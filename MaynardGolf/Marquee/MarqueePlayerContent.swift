import MaynardUI
import SwiftUI

/// Picker content separated from navigation and observation so every state can be previewed (SET-MQ-06).
struct MarqueePlayerContent: View {
    let model: MarqueePlayerViewModel
    let select: (UUID?) -> Void
    let retry: () -> Void
    @State private var avatars = AvatarCache()

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.m) {
                if let error = model.errorMessage {
                    VStack(spacing: DSSpacing.s) {
                        Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                            .accessibilityIdentifier("marqueePlayer.error")
                        Button(action: retry) { Text("Try again", comment: "Retries loading data after an error.") }
                            .buttonStyle(.dsTextLink)
                            .accessibilityIdentifier("marqueePlayer.retry")
                    }
                }
                if model.hasLoaded {
                    CardContainer {
                        Button { select(nil) } label: {
                            SettingsRow(Text("None", comment: "Marquee player: no player is featured on Home.")) {
                                if model.selectedID == nil { Image(systemName: "checkmark").foregroundStyle(Color.ds.link) }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(model.selectedID == nil ? .isSelected : [])
                        .accessibilityIdentifier("marqueePlayer.none")
                        ForEach(model.players) { player in
                            DSDivider()
                            Button { select(player.id) } label: {
                                HStack(spacing: DSSpacing.m) {
                                    PlayerAvatar(name: player.firstName, color: player.color.palette,
                                                 photo: avatars.image(for: player.id, photo: player.photoData), size: .s)
                                    Text(verbatim: player.fullName).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
                                    Spacer(minLength: DSSpacing.s)
                                    if model.selectedID == player.id {
                                        Image(systemName: "checkmark").foregroundStyle(Color.ds.link)
                                    }
                                }
                                .frame(minHeight: 56).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(model.selectedID == player.id ? .isSelected : [])
                            .accessibilityIdentifier("marqueePlayer.player.\(player.id)")
                        }
                    }
                    .disabled(model.isSaving)
                } else if model.errorMessage == nil {
                    ProgressView().accessibilityIdentifier("marqueePlayer.loading")
                }
            }
            .padding(DSSpacing.gutter)
        }
        .background(Color.ds.background.ignoresSafeArea())
        .accessibilityIdentifier("screen.marqueePlayer")
    }
}
