//
//  PlayerFormView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The Add player form, and its Edit configuration from the Player card (05-add-player): the avatar,
/// name fields, an optional handicap index, the color picker and Create (or Save and Delete player).
/// Cancel asks before throwing away changes. The photo controls arrive with #43.
struct PlayerFormView: View {
    @State private var model: PlayerFormViewModel
    /// Called after the player is deleted, so the caller can close the Player card too (AP-ED-07).
    private let onDeleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDiscard = false
    @State private var confirmingDelete = false

    init(model: PlayerFormViewModel, onDeleted: @escaping () -> Void = {}) {
        _model = State(initialValue: model)
        self.onDeleted = onDeleted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                avatar
                names
                handicap
                colors
                submit
                if case .edit = model.mode { deleteRow }
            }
            .padding(.horizontal, DSSpacing.gutter)
            .padding(.vertical, DSSpacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: model.firstName) { model.limitNames() }
        .onChange(of: model.lastName) { model.limitNames() }
        .background(Color.ds.background)
        .dsNavigationBar(Text(verbatim: model.title)) {
            Button { cancel() } label: { Text("Cancel", comment: "Leaves the player form.") }
                .buttonStyle(.dsNeutralPill)
                .accessibilityIdentifier("addPlayer.cancel")
        }
        .interactiveDismissDisabled(model.isDirty)
        .confirmationDialog(model.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button(role: .destructive) { dismiss() } label: { Text("Discard", comment: "Throws away the form's changes.") }
                .accessibilityIdentifier("addPlayer.discard")
            // Not the cancel role: iOS hides a dialog's cancel button, and the spec shows "Keep editing".
            Button {} label: { Text("Keep editing", comment: "Stays on the form.") }
                .accessibilityIdentifier("addPlayer.keepEditing")
        }
        .confirmationDialog(model.deleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button(role: .destructive) {
                if model.delete() {
                    dismiss()
                    onDeleted()
                }
            } label: { Text("Delete player", comment: "Confirms deleting a player.") }
                .accessibilityIdentifier("addPlayer.confirmDelete")
        } message: {
            if let message = model.deleteMessage { Text(verbatim: message) }
        }
        .alert(Text("Something went wrong", comment: "Title of a save or delete error alert."),
               isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button(role: .cancel) {
                if model.isMissing { dismiss() } // nothing to edit
            } label: { Text("OK", comment: "Dismisses an alert.") }
                .accessibilityIdentifier("addPlayer.errorOK")
        } message: {
            Text(verbatim: model.errorMessage ?? "")
        }
    }

    /// The avatar: the photo, or the initial on the chosen color (AP-PH-06).
    private var avatar: some View {
        PlayerAvatar(name: model.displayName, color: model.color.palette,
                     photo: model.photoData.flatMap(UIImage.init(data:)), size: .xxl)
            .accessibilityIdentifier("addPlayer.photo")
    }

    /// First and last name (AP-NM-01…04).
    private var names: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            FormFieldCard(fields: [
                .init(id: "addPlayer.firstName", label: Text("First name", comment: "Label of the first-name field (caps)."),
                      placeholder: String(localized: "e.g. Mark", comment: "Placeholder of the first-name field."),
                      text: $model.firstName, contentType: .givenName, capitalization: .words),
                .init(id: "addPlayer.lastName", label: Text("Last name", comment: "Label of the last-name field (caps)."),
                      placeholder: String(localized: "Optional", comment: "Placeholder of an optional field."),
                      text: $model.lastName, contentType: .familyName, capitalization: .words),
            ])
            if let warning = model.duplicateWarning {
                Text(verbatim: warning).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                    .accessibilityIdentifier("addPlayer.duplicate")
            }
        }
    }

    /// The optional manual index (AP-HC-01…03).
    private var handicap: some View {
        FormFieldCard(fields: [
            .init(id: "addPlayer.handicap", label: Text("Handicap index", comment: "Label of the handicap index field (caps)."),
                  placeholder: String(localized: "e.g. 8.4", comment: "Placeholder of the handicap index field."),
                  text: $model.handicapText, keyboard: .numbersAndPunctuation, capitalization: .never,
                  error: model.handicapError.map { Text(verbatim: $0) }),
        ])
    }

    /// The five swatches (AP-CL-01…03).
    private var colors: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            SectionHeader(Text("Color", comment: "Header above the player color swatches (caps)."))
            CardContainer(radius: DSRadius.card) {
                ColorSwatchPicker(selection: Binding(get: { model.color.palette }, set: { model.color = PlayerColor($0) }),
                                  identifierPrefix: "addPlayer.color")
                    .padding(.vertical, DSSpacing.s)
            }
        }
    }

    /// Create, or Save when editing (AP-CR-01…03, AP-ED-03).
    private var submit: some View {
        Button {
            if model.submit() { dismiss() }
        } label: {
            Text(verbatim: model.submitTitle)
        }
        .buttonStyle(.dsPrimary(height: .large, fullWidth: true))
        .disabled(!model.canSubmit)
        .accessibilityIdentifier(model.mode == .create ? "addPlayer.create" : "addPlayer.save")
    }

    /// Delete player, blocked with a reason while the player is in a round in progress (AP-ED-07).
    private var deleteRow: some View {
        VStack(spacing: DSSpacing.xs) {
            Button(role: .destructive) { confirmingDelete = true } label: {
                Text("Delete player", comment: "Deletes the player being edited.")
            }
            .buttonStyle(.dsTextLink)
            .disabled(!model.canDelete)
            .accessibilityIdentifier("addPlayer.delete")
            if let reason = model.deleteBlockedReason {
                Text(verbatim: reason)
                    .dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("addPlayer.deleteBlocked")
            }
        }
    }

    /// Cancel: closes straight away, or asks first when something changed (AP-NAV-01, AP-ED-04).
    private func cancel() {
        if model.isDirty { confirmingDiscard = true } else { dismiss() }
    }
}

/// The form as a sheet. Its view model is built once, when the sheet is created, not on every render.
struct PlayerFormSheet: View {
    @State private var model: PlayerFormViewModel
    private let router: Router

    init(mode: PlayerFormViewModel.Mode, dependencies: AppDependencies) {
        _model = State(initialValue: PlayerFormViewModel(mode: mode, players: dependencies.players, rounds: dependencies.rounds))
        router = dependencies.router
    }

    var body: some View {
        NavigationStack {
            PlayerFormView(model: model) {
                router.popToRoot() // the Player card it came from is gone too (AP-ED-07)
            }
        }
    }
}

#if DEBUG
/// Which preview player the Edit form opens on.
private enum PreviewEdit {
    case anyone, manualIndex, noManualIndex

    func matches(_ player: Player) -> Bool {
        switch self {
        case .anyone: true
        case .manualIndex: player.handicapIndex != nil
        case .noManualIndex: player.handicapIndex == nil
        }
    }
}

/// A form on the shared preview data. For Edit, the player comes from the same store.
@MainActor
private func previewModel(_ fixture: Fixture = .fullHistory, editing: PreviewEdit? = nil,
                          _ change: (PlayerFormViewModel) -> Void = { _ in }) -> PlayerFormViewModel {
    let dependencies = AppDependencies.preview(fixture)
    let mode: PlayerFormViewModel.Mode = editing
        .flatMap { pick in try? dependencies.players.allPlayers().first(where: pick.matches) }
        .map { .edit($0.id) } ?? .create
    let model = PlayerFormViewModel(mode: mode, players: dependencies.players, rounds: dependencies.rounds)
    change(model)
    return model
}

#Preview("Create, empty") { NavigationStack { PlayerFormView(model: previewModel(.freshInstall)) } }
#Preview("Create, filled in") {
    NavigationStack {
        PlayerFormView(model: previewModel { $0.firstName = "Rory"; $0.lastName = "McIlroy"; $0.handicapText = "+2.1"; $0.color = .flag })
    }
}
#Preview("Create, missing name and invalid index") {
    NavigationStack { PlayerFormView(model: previewModel { $0.lastName = "Woods"; $0.handicapText = "60" }) }
}
#Preview("Create, duplicate name") {
    NavigationStack { PlayerFormView(model: previewModel { $0.firstName = "Tiger"; $0.lastName = "Woods" }) }
}
#Preview("Create, each color") {
    ScrollView {
        ForEach(PlayerColor.allCases, id: \.self) { color in
            NavigationStack {
                PlayerFormView(model: previewModel(.freshInstall) { $0.firstName = color.rawValue.capitalized; $0.color = color })
            }
            .frame(height: 760)
        }
    }
}
#Preview("Edit, plus index") {
    NavigationStack { PlayerFormView(model: previewModel(editing: .manualIndex)) }
}
#Preview("Edit, manual index typed") {
    NavigationStack { PlayerFormView(model: previewModel(editing: .noManualIndex) { $0.handicapText = "8.4" }) }
}
#Preview("Edit, no index") {
    NavigationStack { PlayerFormView(model: previewModel(editing: .noManualIndex)) }
}
#Preview("Edit, in a round in progress") {
    NavigationStack { PlayerFormView(model: previewModel(.inProgress, editing: .anyone)) }
}
#Preview("Create, Dark") {
    NavigationStack { PlayerFormView(model: previewModel { $0.firstName = "Mark" }) }.preferredColorScheme(.dark)
}
#Preview("Create, AX3") {
    NavigationStack { PlayerFormView(model: previewModel { $0.firstName = "Mark"; $0.handicapText = "8.4" }) }
        .dynamicTypeSize(.accessibility3)
}
#endif
