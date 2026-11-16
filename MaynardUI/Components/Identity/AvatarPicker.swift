//
//  AvatarPicker.swift
//  MaynardUI
//

import PhotosUI
import SwiftUI
import UIKit

/// The 104 pt avatar with a camera badge that opens the system photo picker (DS-ID-03): images only,
/// single selection, no camera, and no photo-library permission (X-17). The caller loads the chosen
/// item and passes `isLoading` meanwhile, which shows a spinner over the avatar.
public struct AvatarPicker: View {
    private let name: String
    private let color: PlayerPalette
    private let photo: UIImage?
    private let isLoading: Bool
    @Binding private var selection: PhotosPickerItem?

    public init(name: String, color: PlayerPalette, photo: UIImage?, isLoading: Bool = false,
                selection: Binding<PhotosPickerItem?>) {
        self.name = name
        self.color = color
        self.photo = photo
        self.isLoading = isLoading
        _selection = selection
    }

    public var body: some View {
        let (name, color, photo, isLoading) = (self.name, self.color, self.photo, self.isLoading)
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            AvatarPickerLabel(name: name, color: color, photo: photo, isLoading: isLoading)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(Text(verbatim: Self.accessibilityLabel(hasPhoto: photo != nil)))
    }

    /// "Add photo" or "Change photo".
    public nonisolated static func accessibilityLabel(hasPhoto: Bool) -> String {
        hasPhoto
            ? String(localized: "Change photo", bundle: Bundle.maynardUI, comment: "VoiceOver label of the avatar picker when the player has a photo.")
            : String(localized: "Add photo", bundle: Bundle.maynardUI, comment: "VoiceOver label of the avatar picker when the player has no photo.")
    }
}

/// The picker's label: the avatar, a camera badge and the loading spinner. Public so a screen can use it
/// as the label of its own button or menu (Add player, once a photo is set, AP-PH-03). Its init is
/// nonisolated because PhotosPicker builds its label in a `@Sendable` closure.
public struct AvatarPickerLabel: View {
    let name: String
    let color: PlayerPalette
    let photo: UIImage?
    let isLoading: Bool

    public nonisolated init(name: String, color: PlayerPalette, photo: UIImage?, isLoading: Bool) {
        self.name = name
        self.color = color
        self.photo = photo
        self.isLoading = isLoading
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PlayerAvatar(name: name, color: color, photo: photo, size: .xxl)
                .overlay {
                    if isLoading {
                        Circle().fill(Color.ds.scrim)
                        ProgressView().tint(Color.ds.chalk50)
                    }
                }
            Image(systemName: "camera.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.ds.playerOnDark)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.ds.primaryAction))
                .overlay(Circle().strokeBorder(Color.ds.background, lineWidth: 3))
        }
    }
}
