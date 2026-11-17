//
//  HoleImageCache.swift
//  MaynardGolf
//

import Foundation
import Observation
import UIKit

/// The decoded aerials Hole play keeps: the hole on screen and its neighbours in the round, so a swipe
/// shows the next picture at once, while the rest are released (each decoded crop is about 16 MB).
@MainActor
@Observable
final class HoleImageCache {
    /// Decoded pictures by course hole (1…9).
    private(set) var images: [Int: UIImage] = [:]
    @ObservationIgnored private let provider: HoleImageProviding
    /// The holes the latest `keep` asked for: a slow load that finishes after a later swipe isn't kept.
    @ObservationIgnored private var wanted: Set<Int> = []
    /// Decodes in flight, so overlapping `keep`s wait for one decode instead of starting a second
    /// (#159's review).
    @ObservationIgnored private var loading: [Int: Task<UIImage?, Never>] = [:]

    init(provider: HoleImageProviding) {
        self.provider = provider
    }

    /// Keeps exactly `holes` (course hole numbers), loading the missing ones in the order given (the
    /// hole on screen first) and dropping the others. A cancelled call (the hole changed again) starts
    /// no new decode, so a fast swipe doesn't queue up pictures nobody will see.
    func keep(_ holes: [Int]) async {
        wanted = Set(holes)
        images = images.filter { wanted.contains($0.key) }
        for hole in holes where images[hole] == nil {
            if Task.isCancelled { return }
            let decode = loading[hole] ?? Task { [provider] in await provider.image(forHole: hole) }
            loading[hole] = decode
            let image = await decode.value
            loading[hole] = nil
            if let image, wanted.contains(hole) { images[hole] = image }
        }
    }

    /// The course holes to keep around round hole `current`, the current one first, then the next and
    /// the previous in the round. In an 18-hole round, holes 10…18 replay 1…9, so hole 10's are course
    /// holes 1, 2 and 9.
    nonisolated static func neighbours(of current: Int, in holes: [RoundHole]) -> [Int] {
        // Round hole numbers are 1…n with no repeats (`RoundHoleBuilder`).
        let byNumber = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0.source.number) })
        var ordered: [Int] = []
        for number in [current, current + 1, current - 1] {
            if let source = byNumber[number], !ordered.contains(source) { ordered.append(source) }
        }
        return ordered
    }
}
