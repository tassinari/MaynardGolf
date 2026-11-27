//
//  PhotoCropView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Move and Scale (AP-MS-01…08): the photo behind a 320 pt circle, dimmed outside it, moved by dragging
/// and zoomed by pinching or the slider, with Cancel and Done. Always dark: it's a photo editor. The
/// geometry is `PhotoCropModel`; this view only draws it and feeds it gestures.
struct PhotoCropView: View {
    let image: UIImage
    @State private var crop: PhotoCropModel
    private let onCancel: () -> Void
    private let onDone: (PhotoCropModel) -> Void
    @State private var dragStart: CGSize?
    @State private var zoomStart: CGFloat?

    init(image: UIImage, crop: PhotoCropModel, onCancel: @escaping () -> Void, onDone: @escaping (PhotoCropModel) -> Void) {
        self.image = image
        _crop = State(initialValue: crop)
        self.onCancel = onCancel
        self.onDone = onDone
    }

    var body: some View {
        GeometryReader { geometry in
            let circle = PhotoCropModel.circleDiameter(forWidth: geometry.size.width)
            // Just above the vertical middle (AP-MS-02).
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height * 0.44)
            ZStack {
                Color.ds.imageryBackdrop
                photo(center: center)
                dimming(center: center, circle: circle, size: geometry.size)
                Circle().strokeBorder(Color.ds.onImagery.opacity(0.7), lineWidth: 1.5)
                    .frame(width: circle, height: circle)
                    .position(center)
                    .allowsHitTesting(false)
                controls(circle: circle)
            }
            .onChange(of: circle, initial: true) { crop.resize(circle: circle) }
        }
        .ignoresSafeArea(.container, edges: .all)
        .environment(\.colorScheme, .dark)
    }

    /// The photo, dragged and pinched (AP-MS-03), one VoiceOver element with move and zoom actions (AP-MS-07).
    private func photo(center: CGPoint) -> some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: crop.displayedSize.width, height: crop.displayedSize.height)
            .position(x: center.x + crop.offset.width, y: center.y + crop.offset.height)
            .contentShape(Rectangle())
            .gesture(drag.simultaneously(with: pinch))
            .accessibilityElement()
            .accessibilityLabel(Text("Photo, drag to move, pinch to zoom", comment: "VoiceOver label of the photo in Move and Scale."))
            .accessibilityAction(named: Text("Move up", comment: "VoiceOver action in Move and Scale.")) { crop.step(.up) }
            .accessibilityAction(named: Text("Move down", comment: "VoiceOver action in Move and Scale.")) { crop.step(.down) }
            .accessibilityAction(named: Text("Move left", comment: "VoiceOver action in Move and Scale.")) { crop.step(.left) }
            .accessibilityAction(named: Text("Move right", comment: "VoiceOver action in Move and Scale.")) { crop.step(.right) }
            .accessibilityAction(named: Text("Zoom in", comment: "VoiceOver action in Move and Scale.")) { crop.zoomIn() }
            .accessibilityAction(named: Text("Zoom out", comment: "VoiceOver action in Move and Scale.")) { crop.zoomOut() }
            .accessibilityIdentifier("photoCrop.image")
    }

    /// Black at 55 % everywhere but the circle (AP-MS-02).
    private func dimming(center: CGPoint, circle: CGFloat, size: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addEllipse(in: CGRect(x: center.x - circle / 2, y: center.y - circle / 2, width: circle, height: circle))
        }
        .fill(Color.ds.imageryShadow.opacity(0.55), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    /// The title, the zoom slider and Cancel / Done (AP-MS-01, 05, 06).
    private func controls(circle: CGFloat) -> some View {
        VStack(spacing: DSSpacing.l) {
            Text("Move and Scale", comment: "Title of the photo crop screen.")
                .dsFont(.bodyEmphasized)
                .foregroundStyle(Color.ds.onImagery)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("photoCrop.title")
            Spacer()
            zoomSlider
            HStack {
                Button(action: onCancel) { Text("Cancel", comment: "Leaves Move and Scale without using the photo.") }
                    .foregroundStyle(Color.ds.onImagery)
                    .dsFont(.bodyEmphasized)
                    .frame(minHeight: DSTouchTarget.minimum)
                    .accessibilityIdentifier("photoCrop.cancel")
                Spacer()
                Button { onDone(crop) } label: { Text("Done", comment: "Uses the photo as framed in Move and Scale.") }
                    .buttonStyle(.dsPrimary())
                    .accessibilityIdentifier("photoCrop.done")
            }
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.top, 64)
        .padding(.bottom, 40)
    }

    /// Zoom from 1× to 3×, in step with pinching; VoiceOver reads it as a percentage (AP-MS-05).
    private var zoomSlider: some View {
        HStack(spacing: DSSpacing.m) {
            Image(systemName: "circle").font(.caption).accessibilityHidden(true)
            Slider(value: Binding(get: { crop.zoom }, set: { crop.setZoom($0) }),
                   in: PhotoCropModel.minimumZoom...PhotoCropModel.maximumZoom)
                .tint(Color.ds.onImagery)
                .accessibilityLabel(Text("Zoom", comment: "VoiceOver label of the zoom slider in Move and Scale."))
                .accessibilityValue(Text(verbatim: "\(crop.zoomPercent)%"))
                .accessibilityIdentifier("photoCrop.zoom")
            Image(systemName: "circle").font(.title2).accessibilityHidden(true)
        }
        .foregroundStyle(Color.ds.onImagery)
        .padding(.horizontal, DSSpacing.l)
        .padding(.vertical, DSSpacing.s)
        .dsGlass(cornerRadius: DSRadius.listCard)
        .padding(.horizontal, 12) // with the controls' 20 pt, 32 pt from the edges (AP-MS-05)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? crop.offset
                dragStart = start
                crop.setOffset(CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height))
            }
            .onEnded { _ in dragStart = nil }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = zoomStart ?? crop.zoom
                zoomStart = start
                crop.setZoom(start * value.magnification)
            }
            .onEnded { _ in zoomStart = nil }
    }
}

#if DEBUG
/// Drawn photos of each shape for the previews.
@MainActor
private func previewPhoto(width: CGFloat, height: CGFloat) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        DSColorToken.placeholderTurf.uiColor().setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        DSColorToken.placeholderSand.uiColor().setFill()
        context.cgContext.fillEllipse(in: CGRect(x: width * 0.3, y: height * 0.3, width: width * 0.4, height: height * 0.4))
    }
}

@MainActor
private func previewCrop(_ image: UIImage, zoom: CGFloat = 1, offset: CGSize = .zero) -> some View {
    PhotoCropView(image: image, crop: PhotoCropModel(imageSize: PhotoEncoder.pixelSize(of: image), circle: 320, zoom: zoom, offset: offset),
                  onCancel: {}, onDone: { _ in })
}

#Preview("Landscape, 1×") { previewCrop(MockPhotoLoader.samplePhoto) }
#Preview("Portrait, 1×") { previewCrop(previewPhoto(width: 900, height: 1600)) }
#Preview("Square, 3×") { previewCrop(previewPhoto(width: 1200, height: 1200), zoom: 3) }
#Preview("Clamped at an edge") { previewCrop(MockPhotoLoader.samplePhoto, zoom: 2, offset: CGSize(width: 9_999, height: -9_999)) }
#Preview("From Adjust photo") { previewCrop(MockPhotoLoader.samplePhoto, zoom: 1.6, offset: CGSize(width: -60, height: 20)) }
#Preview("Narrow screen") { previewCrop(MockPhotoLoader.samplePhoto).frame(width: 320) }
#Preview("AX3") { previewCrop(MockPhotoLoader.samplePhoto).dynamicTypeSize(.accessibility3) }
#endif
