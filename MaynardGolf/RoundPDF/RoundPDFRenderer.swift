//
//  RoundPDFRenderer.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation
import SwiftUI

/// The PDF's document info (RP-EX-05): no author or device name.
struct RoundPDFMetadata: Equatable, Sendable {
    /// The file name without ".pdf": "Round · Maynard Golf Club · Nov 8".
    let title: String
    /// "Maynard Golf 1.2".
    let creator: String
    /// "Scorecard".
    let subject: String
}

/// Why the PDF couldn't be made (RP-EX-07).
enum RoundPDFError: Error, Equatable {
    /// Core Graphics couldn't open a PDF context.
    case renderFailed
    /// A UI test asked for a failure (`-uiTestMockPDF fail`, RP-TS-08).
    case injected
}

/// Draws a `RoundPDFModel` as one PDF page (RP-AR-02). A protocol so the exporter's tests use a fake
/// renderer (RP-AR-03).
@MainActor
protocol RoundPDFRendering {
    /// The PDF file's bytes: one 792 × 306 pt page (RP-PG-01, RP-PG-02).
    func render(_ model: RoundPDFModel, metadata: RoundPDFMetadata) async throws -> Data
}

/// The live renderer (RP-AR-02, RP-PG-04): `RoundPDFPage` drawn into a PDF `CGContext` with
/// `ImageRenderer.render(rasterizationScale:renderer:)`, which keeps text as text and shapes as paths, and
/// embeds the fonts as subsets. `ImageRenderer` runs on the main actor; the page is small, so drawing it
/// takes a few tens of milliseconds (RP-EX-02).
struct LiveRoundPDFRenderer: RoundPDFRendering {
    func render(_ model: RoundPDFModel, metadata: RoundPDFMetadata) async throws -> Data {
        try Self.pdfData(for: RoundPDFPage(model: model), metadata: metadata)
    }

    /// One 792 × 306 pt page holding `view`. Split out so tests can wrap the page in a Dark, AX5
    /// environment and show the output doesn't change (RP-TS-05).
    @MainActor
    static func pdfData(for view: some View, metadata: RoundPDFMetadata) throws -> Data {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(RoundPDFPage.size)
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: RoundPDFPage.size)
        let info: [CFString: Any] = [
            kCGPDFContextTitle: metadata.title,
            kCGPDFContextCreator: metadata.creator,
            kCGPDFContextSubject: metadata.subject,
        ]
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, info as CFDictionary) else {
            throw RoundPDFError.renderFailed
        }
        renderer.render { _, draw in
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
}

/// UI-test renderers (`-uiTestMockPDF`, RP-TS-08): one that always fails, so the error alert shows
/// (RP-EX-07), and one that waits first, so the share button's progress shows (RP-EX-02).
struct MockRoundPDFRenderer: RoundPDFRendering {
    enum Behavior: Equatable, Sendable {
        case fail
        case slow(Duration)
    }

    let behavior: Behavior
    var base: RoundPDFRendering = LiveRoundPDFRenderer()

    func render(_ model: RoundPDFModel, metadata: RoundPDFMetadata) async throws -> Data {
        switch behavior {
        case .fail:
            throw RoundPDFError.injected
        case .slow(let delay):
            try await Task.sleep(for: delay)
            return try await base.render(model, metadata: metadata)
        }
    }
}
