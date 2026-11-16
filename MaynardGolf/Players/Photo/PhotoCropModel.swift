//
//  PhotoCropModel.swift
//  MaynardGolf
//

import CoreGraphics

/// Move and Scale's geometry (AP-MS-03, 04, 09): a photo behind a circle, moved and zoomed so it always
/// covers the circle. Pure: the image size (pixels) and circle size (points) in; the clamped offset and
/// zoom, and the crop rectangle in image pixels, out. 100 % unit coverage.
///
/// At 1× the photo's shorter side just fills the circle; zoom runs to 3×. `offset` is where the photo's
/// center sits relative to the circle's center, in points.
struct PhotoCropModel: Equatable, Sendable {
    /// One VoiceOver step (AP-MS-07).
    enum Direction: Sendable { case up, down, left, right }

    static let minimumZoom: CGFloat = 1
    static let maximumZoom: CGFloat = 3
    /// The circle's largest diameter (AP-MS-02).
    static let maximumCircle: CGFloat = 320
    /// VoiceOver moves the photo 10 % of the circle per step (AP-MS-07).
    static let moveStep: CGFloat = 0.1
    /// VoiceOver zooms in or out by this much per step.
    static let zoomStep: CGFloat = 0.25

    let imageSize: CGSize
    private(set) var circle: CGFloat
    private(set) var zoom: CGFloat
    private(set) var offset: CGSize

    /// Starts centered at 1× (AP-MS-04), or where `zoom` and `offset` say (Adjust photo), clamped.
    init(imageSize: CGSize, circle: CGFloat, zoom: CGFloat = 1, offset: CGSize = .zero) {
        self.imageSize = CGSize(width: max(imageSize.width, 1), height: max(imageSize.height, 1))
        self.circle = max(circle, 1)
        self.zoom = Self.minimumZoom
        self.offset = .zero
        setZoom(zoom)
        setOffset(offset)
    }

    /// The circle's diameter for an available width: 320 pt, or the width minus 32 pt on narrow screens
    /// (AP-MS-08, X-19).
    static func circleDiameter(forWidth width: CGFloat) -> CGFloat {
        max(min(maximumCircle, width - 32), 1)
    }

    /// Points per image pixel at 1×.
    private var baseScale: CGFloat { circle / min(imageSize.width, imageSize.height) }

    /// The photo's size on screen at the current zoom.
    var displayedSize: CGSize {
        CGSize(width: imageSize.width * baseScale * zoom, height: imageSize.height * baseScale * zoom)
    }

    /// Zooms about the circle's center, keeping the point under it there, then keeps the circle covered.
    mutating func setZoom(_ value: CGFloat) {
        let clamped = min(max(value, Self.minimumZoom), Self.maximumZoom)
        let ratio = clamped / zoom
        zoom = clamped
        setOffset(CGSize(width: offset.width * ratio, height: offset.height * ratio))
    }

    /// Moves the photo, but never so far that the circle shows an edge (AP-MS-03).
    mutating func setOffset(_ value: CGSize) {
        let limit = CGSize(width: (displayedSize.width - circle) / 2, height: (displayedSize.height - circle) / 2)
        offset = CGSize(width: min(max(value.width, -limit.width), limit.width),
                        height: min(max(value.height, -limit.height), limit.height))
    }

    /// Fits a new circle size (rotation, a different screen) keeping the same framing.
    mutating func resize(circle newCircle: CGFloat) {
        let ratio = max(newCircle, 1) / circle
        circle = max(newCircle, 1)
        setOffset(CGSize(width: offset.width * ratio, height: offset.height * ratio))
    }

    /// One VoiceOver move: the photo goes 10 % of the circle in that direction (AP-MS-07).
    mutating func step(_ direction: Direction) {
        let distance = circle * Self.moveStep
        switch direction {
        case .up: setOffset(CGSize(width: offset.width, height: offset.height - distance))
        case .down: setOffset(CGSize(width: offset.width, height: offset.height + distance))
        case .left: setOffset(CGSize(width: offset.width - distance, height: offset.height))
        case .right: setOffset(CGSize(width: offset.width + distance, height: offset.height))
        }
    }

    mutating func zoomIn() { setZoom(zoom + Self.zoomStep) }
    mutating func zoomOut() { setZoom(zoom - Self.zoomStep) }

    /// The zoom as the slider reads it to VoiceOver: 0 % at 1×, 100 % at 3× (AP-MS-05).
    var zoomPercent: Int { Int(((zoom - Self.minimumZoom) / (Self.maximumZoom - Self.minimumZoom) * 100).rounded()) }

    /// The square of the image, in pixels, that's inside the circle (AP-PH-04).
    var cropRect: CGRect {
        let pointsPerPixel = baseScale * zoom
        let side = circle / pointsPerPixel
        let center = CGPoint(x: imageSize.width / 2 - offset.width / pointsPerPixel,
                             y: imageSize.height / 2 - offset.height / pointsPerPixel)
        return CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }
}
