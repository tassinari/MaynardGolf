//
//  CourseImageryStore.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation
import Observation
import OSLog

/// Keeps only the pieces next to the current hole in memory (16-hole-map HM-MAP-03): its crop, both
/// neighbours' crops and both transitions to them. Moving on releases what's no longer adjacent, cancels
/// loads nobody wants any more and loads the new neighbours in the background, the current hole first.
@Observable
@MainActor
final class CourseImageryStore {
    private(set) var manifest: CourseImagery?
    private(set) var images: [CourseImagePiece: CGImage] = [:]
    /// The most recent failure. A missing piece leaves the rest working: the map shows the dark ground
    /// where it's missing, and a swipe without its pieces crossfades instead (HM-TR-07).
    private(set) var failure: CourseImageryError?

    @ObservationIgnored private var loads: [CourseImagePiece: Task<Void, Never>] = [:]
    @ObservationIgnored private let loader: CourseImageryLoading
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "CourseImagery")

    init(loader: CourseImageryLoading) {
        self.loader = loader
    }

    /// Reads the manifest once.
    func loadManifest() async {
        guard manifest == nil else { return }
        do {
            manifest = try await loader.manifest()
        } catch {
            record(error)
        }
    }

    /// Makes `pieces` the only ones held or loading, loading the missing ones in the order given.
    func focus(on pieces: [CourseImagePiece]) {
        guard let manifest else { return }
        let wanted = Set(pieces)
        for piece in images.keys where !wanted.contains(piece) { images[piece] = nil }
        for (piece, task) in loads where !wanted.contains(piece) {
            task.cancel()
            loads[piece] = nil
        }
        for piece in pieces where images[piece] == nil && loads[piece] == nil {
            guard let placement = manifest.placement(for: piece) else {
                record(CourseImageryError.missingFile("\(piece)"))
                continue
            }
            loads[piece] = Task { [loader] in
                // A cancelled load was already dropped by `focus`, and a newer load may own the slot.
                do {
                    let image = try await loader.image(for: placement)
                    guard !Task.isCancelled else { return }
                    self.images[piece] = image
                } catch {
                    guard !Task.isCancelled else { return }
                    self.record(error)
                }
                self.loads[piece] = nil
            }
        }
    }

    /// Waits for every load that's running (tests and previews).
    func waitForLoads() async {
        while let task = loads.values.first {
            await task.value
        }
    }

    func image(for piece: CourseImagePiece) -> CGImage? { images[piece] }

    private func record(_ error: Error) {
        let failure = error as? CourseImageryError ?? .undecodableFile(String(describing: error))
        log.error("Course imagery: \(String(describing: failure), privacy: .public)")
        self.failure = failure
    }
}
