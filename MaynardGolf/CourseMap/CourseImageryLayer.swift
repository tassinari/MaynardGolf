//
//  CourseImageryLayer.swift
//  MaynardGolf
//

import SwiftUI

/// A loaded piece and where it sits on the master (16-hole-map HM-CD-01).
struct PlacedPiece: Identifiable {
    let image: CGImage
    let placement: ImagePlacement
    /// Fades out over the start of a zoom to the course overview, and back in at its end: the hole's sharp crop,
    /// which is brighter than the overview image, so its outline doesn't show over the course (HM-OV-01, #227).
    var fadesWithZoom = false

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
    /// The progress by which a `fadesWithZoom` piece has faded out (HM-OV-01). Nil: nothing fades (a swipe or a
    /// stretch, which also draw the hole's crop over the overview).
    var zoomFadeEnd: Double?

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
                        .opacity(opacity(of: piece))
                        // A piece added inside a camera animation (the overview, when Course map is pressed) is there
                        // at once: the default fade-in showed black behind the hole until the course faded up (#227).
                        .transition(.identity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    /// 1, or for a `fadesWithZoom` piece on a zoom to the overview, falling to 0 by `zoomFadeEnd`.
    private func opacity(of piece: PlacedPiece) -> Double {
        guard piece.fadesWithZoom, let end = zoomFadeEnd, end > 0 else { return 1 }
        return 1 - min(max(progress / end, 0), 1)
    }
}
