//
//  AppShellTests.swift
//  MaynardGolfTests
//

import Foundation
import Testing

/// The String Catalog's source (X-01, #19).
struct AppShellTests {
    private struct Catalog: Decodable {
        struct Entry: Decodable { let comment: String? }
        let sourceLanguage: String
        let strings: [String: Entry]
    }

    /// X-01: English only, and every entry has a translator comment. English needs no compiled table
    /// (the key is the text), so the catalog source is checked; a Copy Files phase puts it in this test
    /// bundle, so the test doesn't depend on the checkout.
    @Test func everyStringIsEnglishWithAComment() throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "Localizable", withExtension: "xcstrings"))
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        #expect(catalog.sourceLanguage == "en")
        #expect(!catalog.strings.isEmpty)
        for (key, entry) in catalog.strings {
            #expect(entry.comment?.isEmpty == false, "\(key) has no comment")
        }
    }
}

private final class BundleToken {}
