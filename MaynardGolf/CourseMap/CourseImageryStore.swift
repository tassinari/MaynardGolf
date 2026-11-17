//
//  CourseImageryStore.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation
import Observation
import OSLog

/// Keeps only the pieces next to the current hole in memory (16-hole-map HM-MAP-03): its crop, both
/// neighbours' crops and both transitions to them. Moving on releases what's no longer adjacent and
/// loads the new neighbours in the background.
///
/// One worker loads the window a piece at a time, in the order given (the current hole's crop first),
/// re-reading what's wanted after each piece. A decode can't be stopped once started, so this keeps at most
/// one in flight: fast swipes never stack up decodes past the memory budget (#160's review).
@Observable
@MainActor
final class CourseImageryStore {
    private(set) var manifest: CourseImagery?
    private(set) var images: [CourseImagePiece: CGImage] = [:]
    /// The most recent failure, for diagnostics and tests only (it's also logged). The files are bundled,
    /// so retrying wouldn't help and no screen shows it: the map shows the dark ground where a piece is
    /// missing, and a move without its pieces crossfades instead (HM-TR-07, HM-TS-09).
    private(set) var failure: CourseImageryError?

    /// The window, in load order.
    @ObservationIgnored private var wanted: [CourseImagePiece] = []
    /// Pieces that failed: bundled files don't recover, so they aren't retried.
    @ObservationIgnored private var failed: Set<CourseImagePiece> = []
    @ObservationIgnored private var worker: Task<Void, Never>?
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

    /// Makes `pieces` the window: drops the others at once and loads the missing ones in the order given.
    func focus(on pieces: [CourseImagePiece]) {
        guard manifest != nil else { return }
        wanted = pieces
        images = images.filter { pieces.contains($0.key) }
        if worker == nil { worker = Task { await self.loadWanted() } }
    }

    /// Loads the first wanted piece that's missing, then looks again, until the window is complete.
    private func loadWanted() async {
        while let manifest, let piece = wanted.first(where: { images[$0] == nil && !failed.contains($0) }) {
            guard let placement = manifest.placement(for: piece) else {
                failed.insert(piece)
                record(CourseImageryError.missingFile("\(piece)"))
                continue
            }
            do {
                let image = try await loader.image(for: placement)
                if wanted.contains(piece) { images[piece] = image } // a swipe meanwhile may have moved on
            } catch {
                failed.insert(piece)
                if wanted.contains(piece) { record(error) }
            }
        }
        worker = nil
    }

    /// Waits until the window is loaded (tests and previews).
    func waitForLoads() async {
        while let worker { await worker.value }
    }

    func image(for piece: CourseImagePiece) -> CGImage? { images[piece] }

    private func record(_ error: Error) {
        let failure = error as? CourseImageryError ?? .undecodableFile(String(describing: error))
        log.error("Course imagery: \(String(describing: failure), privacy: .public)")
        self.failure = failure
    }
}
