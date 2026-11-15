//
//  CourseMapLoader.swift
//  MaynardGolf
//

import Foundation
import ImageIO
import UIKit

/// The full course map (9780 × 7586) and each hole's camera on it.
struct CourseMap: @unchecked Sendable {
    let image: UIImage
    let layout: CourseMapLayout
}

protocol CourseMapLoading: Sendable {
    func load() async -> CourseMap?
}

/// Live loader: `HoleCameras.json` and `courseMap.heic` from the app bundle, decoded off the main actor.
/// Decoded at full size for now (about 297 MB as a bitmap); tiling and trimming come next.
struct BundleCourseMapLoader: CourseMapLoading {
    private let bundle: Bundle

    init(bundle: Bundle = .main) { self.bundle = bundle }

    func load() async -> CourseMap? {
        guard let layout = Self.layout(in: bundle) else { return nil }
        let name = (layout.map.file as NSString).deletingPathExtension
        let ext = (layout.map.file as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let image = Self.decode(url: url) else { return nil }
            return CourseMap(image: image, layout: layout)
        }.value
    }

    static func layout(in bundle: Bundle) -> CourseMapLayout? {
        guard let url = bundle.url(forResource: "HoleCameras", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CourseMapLayout.self, from: data)
    }

    static func decode(url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
