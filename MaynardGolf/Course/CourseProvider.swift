//
//  CourseProvider.swift
//  MaynardGolf
//

import Foundation

/// Why the course couldn't be loaded (DM-CD-06). A programmer error caught by tests; at run time the
/// app shows the data error screen instead of crashing.
enum CourseError: Error, Equatable, Sendable {
    case missingFile(String)
    case malformed(String)
}

/// Supplies the read-only course (DM-CD-01). Injected, so tests and previews can use their own.
protocol CourseProvider: Sendable {
    func course(id: String) throws -> Course
}

/// Decodes `<id>.json` from the app bundle once per course and caches it.
final class BundleCourseProvider: CourseProvider, @unchecked Sendable {
    // The cache is guarded by `lock`.
    private let bundle: Bundle
    private let lock = NSLock()
    private var cache: [String: Course] = [:]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func course(id: String) throws -> Course {
        if let cached = lock.withLock({ cache[id] }) { return cached }
        guard let url = bundle.url(forResource: id, withExtension: "json") else { throw CourseError.missingFile("\(id).json") }
        let course = try Self.decode(Data(contentsOf: url))
        lock.withLock { cache[id] = course }
        return course
    }

    /// Decodes course JSON, turning any decoding failure into `CourseError.malformed`.
    static func decode(_ data: Data) throws -> Course {
        do {
            return try JSONDecoder().decode(Course.self, from: data)
        } catch {
            throw CourseError.malformed(String(describing: error))
        }
    }
}
