//
//  CourseImageryLayer.swift
//  MaynardGolf
//

import SwiftUI

/// A loaded piece and where it sits on the master (16-hole-map HM-CD-01).
struct PlacedPiece: Identifiable {
    let image: CGImage
    let placement: ImagePlacement

    var id: String { placement.file }
}

/// Draws pieces of the course through a camera blended between two holes (16-hole-map HM-MAP-08).
/// Pieces draw in order, so pass the transition crop first and the hole crops after it: the sharp
/// hole crops stay on top wherever they cover the screen. `progress` is animatable, so SwiftUI
/// animates the pan, rotation and zoom frame by frame.
struct CourseImageryLayer: View, Animatable {
    let pieces: [PlacedPiece]
    let from: ScreenCamera
    let to: ScreenCamera
    var progress: Double
    /// How far below 0 `progress` may draw: 0 for moves between holes, negative for a stretch's bounce (HM-TR-09).
    var lowerBound: Double = 0

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let camera = ScreenCamera.blend(from: from, to: to, progress: progress, lowerBound: lowerBound).transform(screenSize: proxy.size)
            ZStack(alignment: .topLeading) {
                ForEach(pieces) { piece in
                    Image(decorative: piece.image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: piece.placement.width, height: piece.placement.height)
                        .transformEffect(piece.placement.mapTransform.concatenating(camera))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
