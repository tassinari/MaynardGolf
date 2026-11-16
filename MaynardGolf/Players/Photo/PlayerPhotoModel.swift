//
//  PlayerPhotoModel.swift
//  MaynardGolf
//

import Foundation
import Observation
import OSLog
import PhotosUI
import SwiftUI
import UIKit

/// The avatar's photo flow on the player form (AP-PH-01…08, AP-PK-01…04, AP-MS-04, 06): the picker, the
/// loading spinner and failure alert, Move and Scale, and the menu once a photo is set. The finished
/// square JPEG is handed to the form through `apply`, so it's saved only with Create / Save (AP-PH-04).
@MainActor
@Observable
final class PlayerPhotoModel {
    /// Move and Scale on one photo.
    struct CropSession: Identifiable {
        let id: UUID
        let image: UIImage
        var crop: PhotoCropModel
        /// Opened from "Adjust photo": Cancel goes back to the form, not the picker (AP-MS-06).
        let isAdjusting: Bool
    }

    /// The photo on the avatar, nil for the placeholder.
    private(set) var avatar: UIImage?
    /// True while a picked photo loads; the avatar shows a spinner (AP-PH-08).
    private(set) var isLoading = false
    /// Shows "Couldn't load that photo" (AP-PH-08).
    var loadFailed = false
    /// Presents the system photo picker (AP-PK-01).
    var isPickerPresented = false
    /// The picker's selection; the view hands a new one to `picked(_:)`.
    var pickerItem: PhotosPickerItem?
    /// Move and Scale, while it's open.
    var cropSession: CropSession?

    @ObservationIgnored private let loader: PhotoLoading
    @ObservationIgnored private let apply: (Data?) -> Void
    /// The full photo behind the current avatar and where it was framed, for "Adjust photo" (AP-MS-04).
    @ObservationIgnored private var source: UIImage?
    @ObservationIgnored private var lastCrop: PhotoCropModel?
    /// Cancel on a new photo reopens the picker once Move and Scale has finished closing: presenting it
    /// while the cover is still animating away can be dropped by UIKit.
    @ObservationIgnored private var reopenPickerAfterCover = false
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "Players")

    /// `photoData` is the player's current photo (Edit), `apply` receives the new one or nil.
    init(photoData: Data?, loader: PhotoLoading, apply: @escaping (Data?) -> Void) {
        avatar = photoData.flatMap(UIImage.init(data:))
        self.loader = loader
        self.apply = apply
    }

    /// The photo flow for a player form: starts from the form's photo and writes the result back to it.
    static func forForm(_ form: PlayerFormViewModel, loader: PhotoLoading) -> PlayerPhotoModel {
        PlayerPhotoModel(photoData: form.photoData, loader: loader) { [weak form] in form?.photoData = $0 }
    }

    var hasPhoto: Bool { avatar != nil }
    var usesSystemPicker: Bool { loader.usesSystemPicker }

    /// "Add photo" or "Change photo" under the avatar (AP-PH-02).
    var caption: String {
        hasPhoto
            ? String(localized: "Change photo", comment: "Caption under the avatar when the player has a photo.")
            : String(localized: "Add photo", comment: "Caption under the avatar when the player has no photo.")
    }

    /// Opens the picker; a mock loader picks its own photo straight away. With no photo this is what a
    /// tap on the avatar does; with one, it's "Choose new photo" (AP-PH-03).
    func chooseNew() async {
        if usesSystemPicker {
            isPickerPresented = true
        } else {
            await picked(nil)
        }
    }

    /// Loads the chosen photo and opens Move and Scale on it at 1×, centered (AP-PK-03, AP-MS-04). A
    /// failure shows the alert and leaves the avatar as it was (AP-PH-08).
    func picked(_ item: PhotosPickerItem?) async {
        guard !isLoading else { return } // one load at a time
        isLoading = true
        defer {
            isLoading = false
            pickerItem = nil
        }
        do {
            let image = try await loader.load(item)
            cropSession = CropSession(id: UUID(), image: image, crop: PhotoCropModel(imageSize: PhotoEncoder.pixelSize(of: image),
                                                                         circle: PhotoCropModel.maximumCircle),
                                      isAdjusting: false)
        } catch {
            log.error("Couldn't load a picked photo: \(String(describing: error), privacy: .public)")
            loadFailed = true
        }
    }

    /// "Adjust photo": Move and Scale on the current photo, where it was left (AP-PH-03, AP-MS-04). A photo
    /// that was saved earlier (no full photo kept) opens at 1× on the saved square.
    func adjust() {
        guard !isLoading, let image = source ?? avatar else { return }
        let crop = lastCrop ?? PhotoCropModel(imageSize: PhotoEncoder.pixelSize(of: image), circle: PhotoCropModel.maximumCircle)
        cropSession = CropSession(id: UUID(), image: image, crop: crop, isAdjusting: true)
    }

    /// "Remove photo": the placeholder returns at once; it's saved with Create / Save (AP-PH-07).
    func remove() {
        avatar = nil
        source = nil
        lastCrop = nil
        apply(nil)
    }

    /// Done: the crop becomes the avatar and the form's photo (AP-PH-04, AP-MS-06).
    func finishCrop(_ crop: PhotoCropModel) {
        guard let session = cropSession else { return }
        cropSession = nil
        guard let data = PhotoEncoder.squareJPEG(from: session.image, crop: crop.cropRect), let image = UIImage(data: data) else {
            log.error("Couldn't encode a cropped photo")
            loadFailed = true
            return
        }
        source = session.image
        lastCrop = crop
        avatar = image
        apply(data)
    }

    /// Cancel: back to the picker for a new photo, or to the form from "Adjust photo" (AP-MS-06). The
    /// picker reopens from `coverDismissed()`, after the cover has gone. A mock loader has no picker to go
    /// back to, so it returns to the form.
    func cancelCrop() {
        let wasAdjusting = cropSession?.isAdjusting ?? true
        cropSession = nil
        reopenPickerAfterCover = !wasAdjusting && usesSystemPicker
    }

    /// Called when Move and Scale has finished closing: reopens the picker if Cancel asked for it.
    func coverDismissed() {
        if reopenPickerAfterCover { isPickerPresented = true }
        reopenPickerAfterCover = false
    }
}
