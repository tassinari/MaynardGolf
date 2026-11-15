//
//  CourseImageryStore.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation
import Observation
import os

/// Keeps only the pieces next to the current hole in memory (16-hole-map HM-MAP-03): the hole, both
/// neighbours and both swipes out of it. Moving to a hole releases what's no longer adjacent and
/// loads the new neighbours in the background.
@Observable
@MainActor
final class CourseImageryStore {
    private(set) var manifest: CourseImagery?
    private(set) var images: [CourseImagePiece: CGImage] = [:]
    /// The most recent failure. A missing piece leaves the rest working; the screen shows black where it's missing.
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

    /// Makes the window around `hole` the only pieces held or loading. The current hole loads first.
    func focus(on hole: Int) {
        guard let manifest else { return }
        let wanted = CourseImagePiece.window(around: hole, holeCount: manifest.holeCount)
        for piece in images.keys where !wanted.contains(piece) { images[piece] = nil }
        for (piece, task) in loads where !wanted.contains(piece) {
            task.cancel()
            loads[piece] = nil
        }
        let ordered = [CourseImagePiece.hole(hole)] + wanted.subtracting([.hole(hole)]).sorted { "\($0)" < "\($1)" }
        for piece in ordered where images[piece] == nil && loads[piece] == nil {
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

    /// Waits for every load that's running. For tests and previews.
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
