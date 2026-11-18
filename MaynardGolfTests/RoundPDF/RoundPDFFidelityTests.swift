//
//  RoundPDFFidelityTests.swift
//  MaynardGolfTests
//

import CoreGraphics
import Foundation
import PDFKit
import SwiftUI
import Testing
import UIKit
@testable import MaynardGolf

/// 15-round-pdf §7: the real renderer's output, read back with PDFKit (RP-TS-04…07; #78, #112).
@MainActor
struct RoundPDFFidelityTests {
    private let metadata = RoundPDFMetadata(title: "Round · Maynard Golf Club · Nov 8", creator: "Maynard Golf 1.2", subject: "Scorecard")

    /// 18 holes, 4 players: every mark kind (eagle, birdie, par, bogey, double), totals under and over.
    private var eighteen: RoundPDFModel {
        .preview(holeCount: .eighteen, names: ["Mark", "Scottie", "Tiger", "Phil"], offsets: [0, -2, 1, 3])
    }

    /// 9 holes, 2 players, padded with 2 blank rows.
    private var nine: RoundPDFModel { .preview(holeCount: .nine, names: ["Mark", "Kevin"], offsets: [-1, 2]) }

    private func render(_ model: RoundPDFModel) async throws -> Data {
        try await LiveRoundPDFRenderer().render(model, metadata: metadata)
    }

    private func document(_ data: Data) throws -> PDFDocument { try #require(PDFDocument(data: data)) }

    /// The text PDFKit extracts, with runs of whitespace collapsed so line breaks don't matter.
    private func text(_ document: PDFDocument) -> String {
        (document.string ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    // MARK: RP-TS-04

    /// One page, 792 × 306 pt (11 × 4.25 in), and under 300 KB, for both layouts (RP-PG-01, 02, RP-EX-06).
    @Test(arguments: [HoleCount.eighteen, .nine])
    func onePageScorecardSize(holeCount: HoleCount) async throws {
        let data = try await render(holeCount == .eighteen ? eighteen : nine)
        let pdf = try document(data)
        #expect(pdf.pageCount == 1)
        let box = try #require(pdf.page(at: 0)).bounds(for: .mediaBox)
        #expect(box.size == CGSize(width: 792, height: 306))
        #expect(box.width / 72 == 11 && box.height / 72 == 4.25)
        #expect(data.count < 300 * 1024)
    }

    /// The 18-hole page's text is real, searchable text (RP-PG-04): the header, every name and every
    /// total, with OUT / IN / TOT.
    @Test func eighteenHoleText() async throws {
        let model = eighteen
        let text = text(try document(try await render(model)))
        for line in [model.header.eyebrow, model.header.date, "TEE TIME", "OUT", "IN", "TOT", "HOLE", "YARDS", "PAR", "+/−"] {
            #expect(text.contains(line), "missing \(line)")
        }
        for row in model.rows where row.kind == .player {
            #expect(text.contains(row.label))
            for case .text(let total) in row.cells { #expect(text.contains(total), "missing \(total) for \(row.label)") }
        }
    }

    /// The 9-hole page has TOT but no OUT / IN columns (RP-TB-02).
    @Test func nineHoleText() async throws {
        let text = text(try document(try await render(nine)))
        #expect(text.contains("MAYNARD GOLF CLUB · 9-HOLE SCORECARD"))
        #expect(text.contains("FRONT 9"))
        #expect(text.contains("TOT"))
        #expect(!text.contains("OUT"))
        #expect(!text.split(separator: " ").contains("IN"))
    }

    /// Title, Creator and Subject are set; no Author (RP-EX-05).
    @Test func metadataIsSet() async throws {
        let attributes = try document(try await render(nine)).documentAttributes ?? [:]
        #expect(attributes[PDFDocumentAttribute.titleAttribute] as? String == metadata.title)
        #expect(attributes[PDFDocumentAttribute.creatorAttribute] as? String == metadata.creator)
        #expect(attributes[PDFDocumentAttribute.subjectAttribute] as? String == metadata.subject)
        #expect(attributes[PDFDocumentAttribute.authorAttribute] == nil)
    }

    /// Every font on the page is embedded, so it looks the same anywhere (RP-PG-04).
    @Test func fontsAreEmbedded() async throws {
        let data = try await render(eighteen)
        let provider = try #require(CGDataProvider(data: data as CFData))
        let page = try #require(CGPDFDocument(provider)?.page(at: 1))
        let fonts = Self.fonts(of: page)
        #expect(!fonts.isEmpty)
        for (name, embedded) in fonts { #expect(embedded, "font \(name) isn't embedded") }
    }

    // MARK: RP-TS-05

    /// Dark mode and AX5 Dynamic Type around the page change neither its text nor its size (RP-PG-03).
    @Test func darkModeAndAX5DontChangeTheOutput() async throws {
        let model = eighteen
        let plain = try document(try LiveRoundPDFRenderer.pdfData(for: RoundPDFPage(model: model), metadata: metadata))
        let wrapped = RoundPDFPage(model: model).environment(\.colorScheme, .dark).dynamicTypeSize(.accessibility5)
        let changed = try document(try LiveRoundPDFRenderer.pdfData(for: wrapped, metadata: metadata))
        #expect(text(changed) == text(plain))
        #expect(changed.page(at: 0)?.bounds(for: .mediaBox) == plain.page(at: 0)?.bounds(for: .mediaBox))
        let a = try #require(Self.bitmap(plain)), b = try #require(Self.bitmap(changed))
        #expect(Self.difference(a, b) == 0)
    }

    // MARK: RP-TS-06

    /// Page 1 matches its reviewed reference image (RP-TS-06). A missing reference is written next to
    /// this file and the test fails, so a new reference is always looked at before it's checked in.
    @Test(arguments: [("round-pdf-18", HoleCount.eighteen), ("round-pdf-9", .nine)])
    func matchesReferenceImage(name: String, holeCount: HoleCount) async throws {
        let image = try #require(Self.bitmap(try document(try await render(holeCount == .eighteen ? eighteen : nine))))
        // Read from the test bundle, so it works wherever the tests run (CI included).
        guard let path = Bundle(for: FixtureToken.self).path(forResource: name, ofType: "png"),
              let reference = UIImage(contentsOfFile: path) else {
            // Written to the source tree only on the machine that built the tests (RP-TS-06's regenerate flow).
            let url = Self.fixtures.appending(path: "\(name).png")
            try FileManager.default.createDirectory(at: Self.fixtures, withIntermediateDirectories: true)
            try #require(image.pngData()).write(to: url)
            Issue.record("No reference image \(name).png in the test bundle; wrote \(url.path()). Review it against the artboard, add it to MaynardGolfTests' resources and check it in.")
            return
        }
        let difference = Self.difference(image, reference)
        if difference > 0.005, let png = image.pngData() {
            Attachment.record(png, named: "\(name)-actual.png")
        }
        #expect(difference <= 0.005, "\(name) differs from its reference in \(difference * 100) % of pixels")
    }

    // MARK: RP-TS-07

    /// Rendering the 18-hole, 4-player page stays well under 500 ms (best of 3, after a warm-up).
    @Test func renderIsFast() async throws {
        let model = eighteen
        _ = try await render(model)
        var best = Duration.seconds(10)
        for _ in 0..<3 {
            let elapsed = try await ContinuousClock().measure { _ = try await render(model) }
            best = min(best, elapsed)
        }
        #expect(best < .milliseconds(500), "render took \(best)")
    }

    // MARK: Helpers

    /// `MaynardGolfTests/Fixtures/PDF` in the source tree, where a missing reference is written.
    private static let fixtures = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Fixtures/PDF", directoryHint: .isDirectory)

    /// Page 1 drawn at 2× on white.
    private static func bitmap(_ document: PDFDocument) -> UIImage? {
        guard let page = document.page(at: 0) else { return nil }
        let box = page.bounds(for: .mediaBox)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: box.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: box.size))
            context.cgContext.translateBy(x: 0, y: box.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    /// The share of pixels whose color differs by more than 24 / 255 in any channel; 1 when the sizes differ.
    private static func difference(_ a: UIImage, _ b: UIImage) -> Double {
        guard let left = rgba(a), let right = rgba(b), left.count == right.count else { return 1 }
        var differing = 0
        for pixel in stride(from: 0, to: left.count, by: 4) where (0..<3).contains(where: { abs(Int(left[pixel + $0]) - Int(right[pixel + $0])) > 24 }) {
            differing += 1
        }
        return Double(differing) / Double(left.count / 4)
    }

    private static func rgba(_ image: UIImage) -> [UInt8]? {
        guard let cg = image.cgImage else { return nil }
        var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                .map { $0.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height)); return true } ?? false
        }
        return drawn ? pixels : nil
    }

    /// Each font in the page's resources (including Form XObjects) and whether its descriptor has an
    /// embedded font file (FontFile, FontFile2 or FontFile3; Type 3 fonts are drawn from glyph procedures).
    private static func fonts(of page: CGPDFPage) -> [(String, Bool)] {
        var found: [(String, Bool)] = []
        func scan(_ resources: CGPDFDictionaryRef) {
            var fonts: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(resources, "Font", &fonts), let fonts {
                CGPDFDictionaryApplyBlock(fonts, { key, object, _ in
                    var font: CGPDFDictionaryRef?
                    guard CGPDFObjectGetValue(object, .dictionary, &font), let font else { return true }
                    found.append((String(cString: key), Self.isEmbedded(font)))
                    return true
                }, nil)
            }
            var objects: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(resources, "XObject", &objects), let objects {
                CGPDFDictionaryApplyBlock(objects, { _, object, _ in
                    var stream: CGPDFStreamRef?
                    guard CGPDFObjectGetValue(object, .stream, &stream), let stream, let dictionary = CGPDFStreamGetDictionary(stream) else { return true }
                    var nested: CGPDFDictionaryRef?
                    if CGPDFDictionaryGetDictionary(dictionary, "Resources", &nested), let nested { scan(nested) }
                    return true
                }, nil)
            }
        }
        if let pageDictionary = page.dictionary {
            var resources: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(pageDictionary, "Resources", &resources), let resources { scan(resources) }
        }
        return found
    }

    private static func isEmbedded(_ font: CGPDFDictionaryRef) -> Bool {
        var subtype: UnsafePointer<CChar>?
        if CGPDFDictionaryGetName(font, "Subtype", &subtype), let subtype, String(cString: subtype) == "Type3" { return true }
        var descriptor: CGPDFDictionaryRef?
        if !CGPDFDictionaryGetDictionary(font, "FontDescriptor", &descriptor) {
            // A composite font keeps its descriptor on the descendant font.
            var descendants: CGPDFArrayRef?
            var first: CGPDFDictionaryRef?
            if CGPDFDictionaryGetArray(font, "DescendantFonts", &descendants), let descendants,
               CGPDFArrayGetDictionary(descendants, 0, &first), let first {
                CGPDFDictionaryGetDictionary(first, "FontDescriptor", &descriptor)
            }
        }
        guard let descriptor else { return false }
        var stream: CGPDFStreamRef?
        return CGPDFDictionaryGetStream(descriptor, "FontFile", &stream) || CGPDFDictionaryGetStream(descriptor, "FontFile2", &stream)
            || CGPDFDictionaryGetStream(descriptor, "FontFile3", &stream)
    }
}

/// Finds the test bundle (`Bundle(for:)` needs a class) to read the reference images from.
private final class FixtureToken {}
