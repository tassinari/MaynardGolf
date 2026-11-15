//
//  CourseImageryLoader.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation
import ImageIO

enum CourseImageryError: Error, Equatable, Sendable {
    /// `CourseImagery.json` isn't in the bundle (run `tools/cut-course-map.py`).
    case missingManifest
    case unreadableManifest(String)
    case missingFile(String)
    case undecodableFile(String)
}

/// Reads the manifest and decodes pieces. Injected so tests and previews can supply their own.
protocol CourseImageryLoading: Sendable {
    func manifest() async throws -> CourseImagery
    func image(for placement: ImagePlacement) async throws -> CGImage
}

/// Live loader: the `CourseImagery` folder in the app bundle, decoded off the main actor with ImageIO.
struct BundleCourseImageryLoader: CourseImageryLoading {
    static let directory = "CourseImagery"
    private let bundle: Bundle

    init(bundle: Bundle = .main) { self.bundle = bundle }

    /// Whether the cutting script's output is in the bundle.
    var isBundled: Bool { manifestURL != nil }

    private var manifestURL: URL? {
        bundle.url(forResource: "CourseImagery", withExtension: "json", subdirectory: Self.directory)
    }

    func manifest() async throws -> CourseImagery {
        guard let url = manifestURL else { throw CourseImageryError.missingManifest }
        do {
            return try JSONDecoder().decode(CourseImagery.self, from: Data(contentsOf: url))
        } catch {
            throw CourseImageryError.unreadableManifest(String(describing: error))
        }
    }

    func image(for placement: ImagePlacement) async throws -> CGImage {
        let name = (placement.file as NSString).deletingPathExtension
        let ext = (placement.file as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: Self.directory) else {
            throw CourseImageryError.missingFile(placement.file)
        }
        return try await Task.detached(priority: .userInitiated) {
            try Self.decode(url: url)
        }.value
    }

    /// Decodes the whole file at its own size; pieces are already cut to the size they're shown at.
    static func decode(url: URL) throws -> CGImage {
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            throw CourseImageryError.undecodableFile(url.lastPathComponent)
        }
        return image
    }
}
