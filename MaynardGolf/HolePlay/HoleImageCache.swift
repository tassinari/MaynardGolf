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

    init(provider: HoleImageProviding) {
        self.provider = provider
    }

    /// Keeps exactly `holes` (course hole numbers): loads the missing ones and drops the others.
    func keep(_ holes: Set<Int>) async {
        wanted = holes
        images = images.filter { holes.contains($0.key) }
        for hole in holes.sorted() where images[hole] == nil {
            let image = await provider.image(forHole: hole)
            if let image, wanted.contains(hole) { images[hole] = image }
        }
    }

    /// The course holes to keep around round hole `current`: it and the holes before and after it in the
    /// round. In an 18-hole round, holes 10…18 replay 1…9, so hole 10's neighbours are course holes 9 and 2.
    nonisolated static func neighbours(of current: Int, in holes: [RoundHole]) -> Set<Int> {
        Set(holes.filter { abs($0.number - current) <= 1 }.map(\.source.number))
    }
}
