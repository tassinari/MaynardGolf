//
//  Course.swift
//  MaynardGolf
//

import Foundation

/// A point on the course.
struct Coordinate: Codable, Equatable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

/// A green's front, center and back (DM-CD-03), for distances (HP-CTL-03).
struct GreenCoordinates: Codable, Equatable, Hashable, Sendable {
    var front: Coordinate
    var center: Coordinate
    var back: Coordinate
}

/// One set of tees (DM-CD-02). `name` is a String Catalog key (`tee.name.blue`); show `localizedName`.
struct TeeInfo: Codable, Equatable, Hashable, Sendable, Identifiable {
    let id: Tee
    let name: String
    /// The design token for the tee's color dot (00-design-system).
    let colorToken: String
    /// The 18-hole course rating, as printed on the card.
    let rating: Double
    let slope: Int

    var localizedName: String { String(localized: String.LocalizationValue(name)) }

    /// The rating for a round of this length: half the 18-hole rating for 9 holes (course-maynard-gc §2).
    func rating(for holeCount: HoleCount) -> Double {
        holeCount == .eighteen ? rating : rating / 2
    }
}

/// One hole of the 9-hole course (DM-CD-03). Holes 10–18 of an 18-hole round replay these.
struct Hole: Codable, Equatable, Hashable, Sendable, Identifiable {
    let number: Int
    let par: Int
    let yardage: [Tee: Int]
    /// The card's handicap (stroke index) for holes 1–9 of an 18-hole round (CRS-HC-01).
    let handicapFront: Int
    /// The card's handicap for holes 10–18 of an 18-hole round (CRS-HC-01).
    let handicapBack: Int
    let greenCoordinates: GreenCoordinates
    /// Shot-line data (14-shot-lines §6), added by that story. Nil until then.
    let teeCoordinates: [Tee: Coordinate]?
    let landingPoints: [Coordinate]?

    var id: Int { number }

    func yards(from tee: Tee) -> Int { yardage[tee] ?? 0 }
}

/// A local rule (LR-DT-01). Its number is its position; `key` is a String Catalog key (LR-DT-02).
struct LocalRule: Equatable, Hashable, Sendable, Identifiable {
    let id: Int
    let key: String

    var text: String { String(localized: String.LocalizationValue(key)) }
}

/// The bundled, read-only course (DM-CD-01), decoded by `CourseProvider`.
struct Course: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    /// "Maynard Golf Club" (X-16): every screen takes the name from here, never from a literal.
    let name: String
    /// Where weather is looked up (NR-CTA-04).
    let coordinate: Coordinate
    let tees: [TeeInfo]
    let holes: [Hole]
    let localRules: [LocalRule]

    enum CodingKeys: String, CodingKey { case id, name, coordinate, tees, holes, localRules }

    init(id: String, name: String, coordinate: Coordinate, tees: [TeeInfo], holes: [Hole], localRules: [LocalRule]) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.tees = tees
        self.holes = holes
        self.localRules = localRules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let keys = try c.decode([String].self, forKey: .localRules)
        self.init(id: try c.decode(String.self, forKey: .id),
                  name: try c.decode(String.self, forKey: .name),
                  coordinate: try c.decode(Coordinate.self, forKey: .coordinate),
                  tees: try c.decode([TeeInfo].self, forKey: .tees),
                  holes: try c.decode([Hole].self, forKey: .holes).sorted { $0.number < $1.number },
                  localRules: keys.enumerated().map { LocalRule(id: $0.offset + 1, key: $0.element) })
    }

    func tee(_ tee: Tee) -> TeeInfo? { tees.first { $0.id == tee } }
}

extension Tee: CodingKeyRepresentable {}
