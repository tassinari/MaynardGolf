//
//  PreviewCourseImagery.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation
import UIKit

/// A small made-up course for previews: nine cameras around a 3000 × 2000 master. Hole crops are
/// coloured cards with the hole number; transition crops are the whole master as a grid. The
/// pieces differ on purpose so the layering is easy to see.
struct PreviewCourseImageryLoader: CourseImageryLoading {
    var failing = false

    static let masterSize = CGSize(width: 3000, height: 2000)
    private static let holePixels = CGSize(width: 256, height: 512)
    private static let transitionDivisor = 8.0

    func manifest() async throws -> CourseImagery {
        if failing { throw CourseImageryError.missingManifest }
        return Self.imagery
    }

    func image(for placement: ImagePlacement) async throws -> CGImage {
        if failing { throw CourseImageryError.missingFile(placement.file) }
        let size = placement.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            if placement.file.hasPrefix("hole") {
                Self.drawHole(placement, in: context.cgContext, size: size)
            } else {
                Self.drawMaster(in: context.cgContext, scale: 1 / placement.mapPixelsPerPixel)
            }
        }
        guard let cgImage = image.cgImage else { throw CourseImageryError.undecodableFile(placement.file) }
        return cgImage
    }

    static let imagery: CourseImagery = {
        let centers: [(Double, Double, Double)] = [ // x, y, rotation°
            (600, 1300, 0), (900, 600, 100), (1500, 800, -60), (1300, 1500, 170), (2000, 1400, 10),
            (2300, 700, 120), (2600, 1300, -30), (2200, 1700, 80), (1000, 1700, -100),
        ]
        let mppp = 0.25
        let holes = centers.enumerated().map { index, entry in
            let camera = HoleCamera(hole: index + 1, mapCenter: CGPoint(x: entry.0, y: entry.1),
                                    rotationDegrees: entry.2, mapPixelsPerHolePixel: mppp)
            let theta = entry.2 * .pi / 180
            let half = CGPoint(x: 1024 * mppp, y: 2048 * mppp)
            let origin = CGPoint(x: entry.0 - (cos(theta) * half.x - sin(theta) * half.y),
                                 y: entry.1 - (sin(theta) * half.x + cos(theta) * half.y))
            let image = ImagePlacement(file: "hole\(index + 1).heic", width: holePixels.width, height: holePixels.height,
                                       mapOrigin: origin, rotationDegrees: entry.2,
                                       mapPixelsPerPixel: 2048 * mppp / holePixels.width)
            return CourseImagery.Hole(camera: camera, image: image)
        }
        let transitions = (1...9).map { from in
            CourseImagery.Transition(from: from, to: from % 9 + 1, image: ImagePlacement(
                file: "transition-\(from)-\(from % 9 + 1).heic",
                width: masterSize.width / transitionDivisor, height: masterSize.height / transitionDivisor,
                mapOrigin: .zero, rotationDegrees: 0, mapPixelsPerPixel: transitionDivisor))
        }
        return CourseImagery(master: .init(width: masterSize.width, height: masterSize.height, boundsSWNE: [0, 0, 1, 1]),
                             holeImage: .init(width: 2048, height: 4096), holes: holes, transitions: transitions)
    }()

    private static func drawHole(_ placement: ImagePlacement, in context: CGContext, size: CGSize) {
        let number = Int(placement.file.dropFirst(4).prefix { $0.isNumber }) ?? 0
        UIColor(hue: Double(number) / 9, saturation: 0.45, brightness: 0.75, alpha: 1).setFill()
        context.fill(CGRect(origin: .zero, size: size))
        let text = NSAttributedString(string: "\(number)", attributes: [
            .font: UIFont.systemFont(ofSize: size.width * 0.6, weight: .bold), .foregroundColor: UIColor.white,
        ])
        let bounds = text.size()
        text.draw(at: CGPoint(x: (size.width - bounds.width) / 2, y: (size.height - bounds.height) / 2))
    }

    private static func drawMaster(in context: CGContext, scale: Double) {
        context.scaleBy(x: scale, y: scale)
        UIColor(red: 0.18, green: 0.36, blue: 0.16, alpha: 1).setFill()
        context.fill(CGRect(origin: .zero, size: masterSize))
        UIColor(white: 1, alpha: 0.35).setStroke()
        context.setLineWidth(8)
        for x in stride(from: 0.0, through: masterSize.width, by: 250) {
            context.strokeLineSegments(between: [CGPoint(x: x, y: 0), CGPoint(x: x, y: masterSize.height)])
        }
        for y in stride(from: 0.0, through: masterSize.height, by: 250) {
            context.strokeLineSegments(between: [CGPoint(x: 0, y: y), CGPoint(x: masterSize.width, y: y)])
        }
    }
}

extension CourseImageryStore {
    /// A store over the made-up preview course.
    static func preview() -> CourseImageryStore {
        CourseImageryStore(loader: PreviewCourseImageryLoader())
    }
}
