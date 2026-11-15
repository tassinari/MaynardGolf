//
//  AppShellTests.swift
//  MaynardGolfTests
//

import Foundation
import Testing
@testable import MaynardGolf

/// Checks on the placeholder app shell until Foundation (#14) replaces it.
struct AppShellTests {
    private struct Catalog: Decodable {
        struct Entry: Decodable { let comment: String? }
        let sourceLanguage: String
        let strings: [String: Entry]
    }

    /// X-01: the placeholder title is an English String Catalog entry with a translator comment.
    /// English needs no compiled table (the key is the text), so the catalog source is checked.
    @Test func placeholderTitleIsInTheStringCatalog() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "MaynardGolf/Localizable.xcstrings")
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        #expect(catalog.sourceLanguage == "en")
        let entry = try #require(catalog.strings["Maynard Golf"])
        #expect(entry.comment?.isEmpty == false)
    }
}
