//
//  PlayerFormView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The Add player form, and its Edit configuration from the Player card (05-add-player): the avatar,
/// name fields, an optional starting index (until the player has a calculated one), the color picker and Create (or Save and Delete player).
/// Cancel asks before throwing away changes.
struct PlayerFormView: View {
    @State private var model: PlayerFormViewModel
    @State private var photo: PlayerPhotoModel
    /// Called after the player is deleted, so the caller can close the Player card too (AP-ED-07).
    private let onDeleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDiscard = false
    @State private var confirmingDelete = false

    /// `photo` runs the avatar's photo flow for this form (`PlayerPhotoModel.forForm`).
    init(model: PlayerFormViewModel, photo: PlayerPhotoModel, onDeleted: @escaping () -> Void = {}) {
        _model = State(initialValue: model)
        _photo = State(initialValue: photo)
        self.onDeleted = onDeleted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                avatar
                names
                if model.showsStartingIndex { handicap }
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
        .fullScreenCover(item: $photo.cropSession, onDismiss: photo.coverDismissed) { session in
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
            .disabled(photo.isLoading)
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

    /// The optional starting index and its hint (AP-HC-01…05, #268); only while the player has no calculated index.
    private var handicap: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            FormFieldCard(fields: [
                .init(id: "addPlayer.handicap",
                      label: Text("Starting index", comment: "Add / Edit player: the label of the starting handicap index field, shown in caps."),
                      placeholder: String(localized: "e.g. 8.4", comment: "Placeholder of the handicap index field."),
                      text: $model.handicapText, keyboard: .decimalPad, capitalization: .never,
                      error: model.handicapError.map { Text(verbatim: $0) }),
            ])
            // The decimal pad has no "+": a ± key over it, only while this card's field is focused (AP-HC-02).
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button(action: model.togglePlusHandicap) { Text(verbatim: "+/−").dsNumeric() }
                        .accessibilityLabel(Text("Plus handicap", comment: "Add / Edit player: the key over the number pad that adds or removes the + of a plus handicap."))
                        .accessibilityIdentifier("addPlayer.handicap.plus")
                    Spacer()
                }
            }
            Text("Used until 3 rounds are played. Add recent scores from other courses on the Handicap screen to start from your real index.",
                 comment: "Add / Edit player: the hint under the Starting index field.")
                .dsFont(.caption)
                .foregroundStyle(Color.ds.textSecondary)
                .accessibilityIdentifier("addPlayer.handicapHint")
        }
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

/// The form as a sheet. Its view models are built once, when the sheet is created, not on every render.
struct PlayerFormSheet: View {
    @State private var model: PlayerFormViewModel
    @State private var photo: PlayerPhotoModel
    private let router: Router
    private let mode: PlayerFormViewModel.Mode

    init(mode: PlayerFormViewModel.Mode, dependencies: AppDependencies) {
        let model = PlayerFormViewModel(mode: mode, players: dependencies.players, rounds: dependencies.rounds,
                                        showsStartingIndex: { [handicaps = dependencies.handicaps] in
                                            Self.showsStartingIndex(mode, handicaps: handicaps)
                                        })
        _model = State(initialValue: model)
        _photo = State(initialValue: .forForm(model, loader: dependencies.photos))
        router = dependencies.router
        self.mode = mode
    }

    /// The Starting index field is offered until the player has a calculated index (AP-HC-05).
    static func showsStartingIndex(_ mode: PlayerFormViewModel.Mode, handicaps: HandicapManager) -> Bool {
        guard case .edit(let id) = mode else { return true }
        return handicaps.handicap(for: id).source != .calculated
    }

    var body: some View {
        NavigationStack {
            PlayerFormView(model: model, photo: photo) {
                // The Player card it came from is gone too; back to the screen before it (AP-ED-07, PC-TOP-03).
                if case .edit(let id) = mode { router.close(.playerCard(id)) }
            }
        }
    }
}

#if DEBUG
/// A form view on a preview model, with a mock photo loader.
@MainActor
private func previewForm(_ model: PlayerFormViewModel) -> PlayerFormView {
    PlayerFormView(model: model, photo: .forForm(model, loader: MockPhotoLoader()))
}

/// Which preview player the Edit form opens on.
private enum PreviewEdit {
    case anyone, startingIndex, noStartingIndex
    /// A player with a calculated index: the Starting index field is hidden (AP-HC-05).
    case calculated
    /// A player id that isn't in the store (deleted elsewhere).
    case missing

    func matches(_ player: Player) -> Bool {
        switch self {
        case .anyone, .calculated: true
        case .startingIndex: player.handicapIndex != nil
        case .noStartingIndex: player.handicapIndex == nil
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
    let model = PlayerFormViewModel(mode: mode, players: dependencies.players, rounds: dependencies.rounds,
                                    showsStartingIndex: { editing != .calculated })
    change(model)
    return model
}

#Preview("Create, empty") { NavigationStack { previewForm(previewModel(.freshInstall)) } }
#Preview("Create, filled in") {
    NavigationStack {
        previewForm(previewModel { $0.firstName = "Rory"; $0.lastName = "McIlroy"; $0.handicapText = "+2.1"; $0.color = .flag })
    }
}
#Preview("Create, missing name and invalid index") {
    NavigationStack { previewForm(previewModel { $0.lastName = "Woods"; $0.handicapText = "60" }) }
}
#Preview("Create, duplicate name") {
    NavigationStack { previewForm(previewModel { $0.firstName = "Tiger"; $0.lastName = "Woods" }) }
}
#Preview("Create, each color") {
    ScrollView {
        ForEach(PlayerColor.allCases, id: \.self) { color in
            NavigationStack {
                previewForm(previewModel(.freshInstall) { $0.firstName = color.rawValue.capitalized; $0.color = color })
            }
            .frame(height: 760)
        }
    }
}
#Preview("Edit, plus index") {
    NavigationStack { previewForm(previewModel(editing: .startingIndex)) }
}
#Preview("Edit, calculated index: no Starting index field") {
    NavigationStack { previewForm(previewModel(editing: .calculated)) }
}
#Preview("Edit, starting index typed") {
    NavigationStack { previewForm(previewModel(editing: .noStartingIndex) { $0.handicapText = "8.4" }) }
}
#Preview("Edit, no index") {
    NavigationStack { previewForm(previewModel(editing: .noStartingIndex)) }
}
#Preview("Edit, in a round in progress") {
    NavigationStack { previewForm(previewModel(.inProgress, editing: .anyone)) }
}
#Preview("Edit, with a photo") {
    NavigationStack {
        previewForm(previewModel(editing: .anyone) {
            $0.photoData = PhotoEncoder.squareJPEG(from: MockPhotoLoader.samplePhoto, crop: CGRect(x: 300, y: 100, width: 1000, height: 1000))
        })
    }
}
#Preview("Edit, player no longer exists") {
    NavigationStack { previewForm(previewModel(editing: .missing)) }
}
#Preview("Create, Dark") {
    NavigationStack { previewForm(previewModel { $0.firstName = "Mark" }) }.preferredColorScheme(.dark)
}
#Preview("Create, AX3") {
    NavigationStack { previewForm(previewModel { $0.firstName = "Mark"; $0.handicapText = "8.4" }) }
        .dynamicTypeSize(.accessibility3)
}
#endif
