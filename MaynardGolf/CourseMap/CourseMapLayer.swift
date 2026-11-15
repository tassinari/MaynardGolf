//
//  CourseMapLayer.swift
//  MaynardGolf
//

import SwiftUI

/// Draws the course map seen through a camera blended between two holes. `progress` is animatable,
/// so SwiftUI animates the pan, rotation and zoom frame by frame.
struct CourseMapLayer: View, Animatable {
    let image: UIImage
    let from: ScreenCamera
    let to: ScreenCamera
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let camera = ScreenCamera.blend(from: from, to: to, progress: progress)
            Image(uiImage: image)
                .resizable()
                .frame(width: image.size.width, height: image.size.height)
                .transformEffect(camera.transform(screenSize: proxy.size))
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
