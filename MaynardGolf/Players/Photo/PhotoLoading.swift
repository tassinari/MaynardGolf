//
//  PhotoLoading.swift
//  MaynardGolf
//

import MaynardUI
import PhotosUI
import SwiftUI
import UIKit

/// Loads the photo the player chose (AP-PH-05, 08), injected so UI tests can stand in for the system
/// picker, which they can't drive (`-uiTestMockPhoto success|fail`).
@MainActor
protocol PhotoLoading: AnyObject {
    /// True for the live loader: the avatar opens the system `PhotosPicker`. A mock skips the picker and
    /// "picks" its own photo straight away.
    var usesSystemPicker: Bool { get }
    /// The chosen photo. `item` is the picker's selection (nil for a mock). Throws when it can't be loaded.
    func load(_ item: PhotosPickerItem?) async throws -> UIImage
}

/// Why a photo couldn't be loaded.
enum PhotoLoadError: Error, Equatable { case unreadable }

/// The system picker's photo, loaded as data and decoded downsampled off the main actor
/// (`PhotoEncoder.downsampled`). The picker runs out of process and hands over only this photo, so
/// there's no permission prompt (AP-PH-05).
@MainActor
final class LivePhotoLoader: PhotoLoading {
    let usesSystemPicker = true

    func load(_ item: PhotosPickerItem?) async throws -> UIImage {
        guard let item, let data = try await item.loadTransferable(type: Data.self),
              let image = await Self.decode(data) else {
            throw PhotoLoadError.unreadable
        }
        return image
    }

    @concurrent
    nonisolated static func decode(_ data: Data) async -> UIImage? {
        PhotoEncoder.downsampled(data)
    }
}

/// A fixed landscape photo, or a failure, for UI tests and previews.
@MainActor
final class MockPhotoLoader: PhotoLoading {
    let usesSystemPicker = false
    private let fails: Bool

    init(fails: Bool = false) { self.fails = fails }

    func load(_ item: PhotosPickerItem?) async throws -> UIImage {
        if fails { throw PhotoLoadError.unreadable }
        return Self.samplePhoto
    }

    /// A drawn 1600 × 1200 "photo" (no image files): stripes and a disc, so moving and zooming show.
    static let samplePhoto: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 1200), format: format).image { context in
            for index in 0..<8 {
                (index.isMultiple(of: 2) ? DSColorToken.placeholderTurf : DSColorToken.placeholderTurfStripe).uiColor().setFill()
                context.fill(CGRect(x: CGFloat(index) * 200, y: 0, width: 200, height: 1200))
            }
            DSColorToken.placeholderSand.uiColor().setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 600, y: 400, width: 400, height: 400))
        }
    }()
}
