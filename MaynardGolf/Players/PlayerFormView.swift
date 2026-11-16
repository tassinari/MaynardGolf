//
//  PlayerFormView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The Add player form, and its Edit configuration from the Player card (05-add-player): the avatar,
/// name fields, an optional handicap index, the color picker and Create (or Save and Delete player).
/// Cancel asks before throwing away changes.
struct PlayerFormView: View {
    @State private var model: PlayerFormViewModel
    @State private var photo: PlayerPhotoModel
    /// Called after the player is deleted, so the caller can close the Player card too (AP-ED-07).
    private let onDeleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDiscard = false
    @State private var confirmingDelete = false

    /// `photos` loads the photo picked for the avatar (`AppDependencies.photos`).
    init(model: PlayerFormViewModel, photos: PhotoLoading, onDeleted: @escaping () -> Void = {}) {
        _model = State(initialValue: model)
        _photo = State(initialValue: PlayerPhotoModel(photoData: model.photoData, loader: photos) { [model] in
            model.photoData = $0
        })
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

    /// The avatar and its caption (AP-PH-01…03): with no photo a tap opens the picker; with one, a menu
    /// offers Choose new / Adjust / Remove. The photo, or the initial on the chosen color (AP-PH-06).
    private var avatar: some View {
        VStack(spacing: DSSpacing.xs) {
            photoControl {
                AvatarPickerLabel(name: model.displayName, color: model.color.palette, photo: photo.avatar, isLoading: photo.isLoading)
            }
            .accessibilityLabel(Text(verbatim: photoLabel))
            .accessibilityIdentifier("addPlayer.photo")
            photoControl {
                Text(verbatim: photo.caption).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.link)
            }
            .accessibilityIdentifier("addPlayer.photoCaption")
        }
        .photosPicker(isPresented: $photo.isPickerPresented, selection: $photo.pickerItem, matching: .images,
                      photoLibrary: .shared())
        .onChange(of: photo.pickerItem) { _, item in
            if let item { Task { await photo.picked(item) } }
        }
        .fullScreenCover(item: $photo.cropSession) { session in
            PhotoCropView(image: session.image, crop: session.crop, onCancel: photo.cancelCrop, onDone: photo.finishCrop)
        }
        .alert(Text("Couldn't load that photo", comment: "Alert when a picked photo can't be loaded."), isPresented: $photo.loadFailed) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
                .accessibilityIdentifier("addPlayer.photoErrorOK")
        }
    }

    /// "Add photo", or "Photo of Mark, change photo" (AP-PH-01).
    private var photoLabel: String {
        photo.hasPhoto
            ? String(localized: "Photo of \(model.displayName), change photo", comment: "VoiceOver label of the avatar when the player has a photo.")
            : photo.caption
    }

    /// A tap target for the photo: the picker with no photo, the menu with one (AP-PH-03).
    @ViewBuilder
    private func photoControl<Content: View>(@ViewBuilder label: () -> Content) -> some View {
        if photo.hasPhoto {
            Menu {
                Button { Task { await photo.chooseNew() } } label: {
                    Label { Text("Choose new photo", comment: "Avatar menu item.") } icon: { Image(systemName: "photo.on.rectangle") }
                }
                .accessibilityIdentifier("addPlayer.photoMenu.choose")
                Button { photo.adjust() } label: {
                    Label { Text("Adjust photo", comment: "Avatar menu item: reopens Move and Scale.") } icon: { Image(systemName: "crop") }
                }
                .accessibilityIdentifier("addPlayer.photoMenu.adjust")
                Button(role: .destructive) { photo.remove() } label: {
                    Label { Text("Remove photo", comment: "Avatar menu item.") } icon: { Image(systemName: "trash") }
                }
                .accessibilityIdentifier("addPlayer.photoMenu.remove")
            } label: {
                label()
            }
            .buttonStyle(.plain)
        } else {
            Button { Task { await photo.chooseNew() } } label: { label() }
                .buttonStyle(.plain)
                .disabled(photo.isLoading)
        }
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
    private let photos: PhotoLoading

    init(mode: PlayerFormViewModel.Mode, dependencies: AppDependencies) {
        _model = State(initialValue: PlayerFormViewModel(mode: mode, players: dependencies.players, rounds: dependencies.rounds))
        router = dependencies.router
        photos = dependencies.photos
    }

    var body: some View {
        NavigationStack {
            PlayerFormView(model: model, photos: photos) {
                router.popToRoot() // the Player card it came from is gone too (AP-ED-07)
            }
        }
    }
}

#if DEBUG
/// Which preview player the Edit form opens on.
private enum PreviewEdit {
    case anyone, manualIndex, noManualIndex
    /// A player id that isn't in the store (deleted elsewhere).
    case missing

    func matches(_ player: Player) -> Bool {
        switch self {
        case .anyone: true
        case .manualIndex: player.handicapIndex != nil
        case .noManualIndex: player.handicapIndex == nil
        case .missing: false
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
        .map { .edit($0.id) } ?? (editing == .missing ? .edit(UUID()) : .create)
    let model = PlayerFormViewModel(mode: mode, players: dependencies.players, rounds: dependencies.rounds)
    change(model)
    return model
}

#Preview("Create, empty") { NavigationStack { PlayerFormView(model: previewModel(.freshInstall), photos: MockPhotoLoader()) } }
#Preview("Create, filled in") {
    NavigationStack {
        PlayerFormView(model: previewModel { $0.firstName = "Rory"; $0.lastName = "McIlroy"; $0.handicapText = "+2.1"; $0.color = .flag }, photos: MockPhotoLoader())
    }
}
#Preview("Create, missing name and invalid index") {
    NavigationStack { PlayerFormView(model: previewModel { $0.lastName = "Woods"; $0.handicapText = "60" }, photos: MockPhotoLoader()) }
}
#Preview("Create, duplicate name") {
    NavigationStack { PlayerFormView(model: previewModel { $0.firstName = "Tiger"; $0.lastName = "Woods" }, photos: MockPhotoLoader()) }
}
#Preview("Create, each color") {
    ScrollView {
        ForEach(PlayerColor.allCases, id: \.self) { color in
            NavigationStack {
                PlayerFormView(model: previewModel(.freshInstall) { $0.firstName = color.rawValue.capitalized; $0.color = color }, photos: MockPhotoLoader())
            }
            .frame(height: 760)
        }
    }
}
#Preview("Edit, plus index") {
    NavigationStack { PlayerFormView(model: previewModel(editing: .manualIndex), photos: MockPhotoLoader()) }
}
#Preview("Edit, manual index typed") {
    NavigationStack { PlayerFormView(model: previewModel(editing: .noManualIndex) { $0.handicapText = "8.4" }, photos: MockPhotoLoader()) }
}
#Preview("Edit, no index") {
    NavigationStack { PlayerFormView(model: previewModel(editing: .noManualIndex), photos: MockPhotoLoader()) }
}
#Preview("Edit, in a round in progress") {
    NavigationStack { PlayerFormView(model: previewModel(.inProgress, editing: .anyone), photos: MockPhotoLoader()) }
}
#Preview("Edit, with a photo") {
    NavigationStack {
        PlayerFormView(model: previewModel(editing: .anyone) {
            $0.photoData = PhotoEncoder.squareJPEG(from: MockPhotoLoader.samplePhoto, crop: CGRect(x: 300, y: 100, width: 1000, height: 1000))
        }, photos: MockPhotoLoader())
    }
}
#Preview("Edit, player no longer exists") {
    NavigationStack { PlayerFormView(model: previewModel(editing: .missing), photos: MockPhotoLoader()) }
}
#Preview("Create, Dark") {
    NavigationStack { PlayerFormView(model: previewModel { $0.firstName = "Mark" }, photos: MockPhotoLoader()) }.preferredColorScheme(.dark)
}
#Preview("Create, AX3") {
    NavigationStack { PlayerFormView(model: previewModel { $0.firstName = "Mark"; $0.handicapText = "8.4" }, photos: MockPhotoLoader()) }
        .dynamicTypeSize(.accessibility3)
}
#endif
