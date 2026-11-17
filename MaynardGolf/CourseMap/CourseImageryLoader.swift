//
//  CourseImageryLoader.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation
import ImageIO

/// Why a piece of the course map couldn't be loaded (HM-TS-09: an error, never a crash).
enum CourseImageryError: Error, Equatable, Sendable {
    /// `CourseImagery.json` isn't in the bundle (run `tools/cut-course-map.py`).
    case missingManifest
    case unreadableManifest(String)
    case missingFile(String)
    case undecodableFile(String)
}

/// Reads the manifest and decodes pieces (16-hole-map §2, §6). Injected so tests and previews can supply
/// their own.
protocol CourseImageryLoading: Sendable {
    func manifest() async throws -> CourseImagery
    func image(for placement: ImagePlacement) async throws -> CGImage
}

/// The cutting script's output in the app bundle (`MaynardGolf/CourseImagery/`, added to the target
/// file by file, so it sits at the bundle's root). Pieces decode off the main actor, in full, at their
/// own size: they're already cut to the size they're shown at.
struct BundleCourseImageryLoader: CourseImageryLoading {
    /// Where the files are: the app bundle's resources by default.
    let directory: URL?

    init(directory: URL? = Bundle.main.resourceURL) {
        self.directory = directory
    }

    @concurrent
    func manifest() async throws -> CourseImagery {
        guard let url = directory?.appendingPathComponent("CourseImagery.json"),
              FileManager.default.fileExists(atPath: url.path) else { throw CourseImageryError.missingManifest }
        do {
            return try JSONDecoder().decode(CourseImagery.self, from: Data(contentsOf: url))
        } catch {
            throw CourseImageryError.unreadableManifest(String(describing: error))
        }
    }

    @concurrent
    func image(for placement: ImagePlacement) async throws -> CGImage {
        guard let url = directory?.appendingPathComponent(placement.file),
              FileManager.default.fileExists(atPath: url.path) else { throw CourseImageryError.missingFile(placement.file) }
        return try Self.decode(url: url)
    }

    /// Decodes now, not lazily at first draw, so a swipe never decodes on the main thread (HM-TR-07).
    nonisolated static func decode(url: URL) throws -> CGImage {
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            throw CourseImageryError.undecodableFile(url.lastPathComponent)
        }
        return image
    }
}
