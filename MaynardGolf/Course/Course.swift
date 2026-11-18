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

extension Tee {
    /// The String Catalog key of the tee's name (`tee.name.blue`), the same key the course data uses.
    var nameKey: String { "tee.name.\(rawValue)" }

    /// "Blue": the tee's name when the course data has no `TeeInfo` for it (HOME-RR-03).
    var localizedName: String { String(localized: String.LocalizationValue(nameKey)) }
}

/// Where each tee's box is on a hole (SL-CD-01): one GPS point per tee, all four required.
struct TeeBoxes: Equatable, Hashable, Sendable {
    let blue: Coordinate
    let white: Coordinate
    let yellow: Coordinate
    let red: Coordinate

    subscript(tee: Tee) -> Coordinate {
        switch tee {
        case .blue: blue
        case .white: white
        case .yellow: yellow
        case .red: red
        }
    }
}

/// Course data that decodes but breaks a rule the shot lines rely on (SL-CD-01, 02).
enum CourseDataError: Error, Equatable {
    /// The hole has no `teeBoxes` entry for this tee.
    case missingTeeBox(hole: Int, tee: Tee)
    /// The hole's `approachShots` don't match its par: two for a par 5, one otherwise.
    case approachShotCount(hole: Int, par: Int, found: Int)
}

/// One hole of the 9-hole course (DM-CD-03). Holes 10–18 of an 18-hole round replay these.
struct Hole: Decodable, Equatable, Hashable, Sendable, Identifiable {
    let number: Int
    let par: Int
    let yardage: [Tee: Int]
    /// The card's handicap (stroke index) for holes 1–9 of an 18-hole round (CRS-HC-01).
    let handicapFront: Int
    /// The card's handicap for holes 10–18 of an 18-hole round (CRS-HC-01).
    let handicapBack: Int
    /// The pin is `greenCoordinates.center` (SL-CD-04).
    let greenCoordinates: GreenCoordinates
    /// Each tee's box (SL-CD-01): where the shot line starts.
    let teeBoxes: TeeBoxes
    /// The suggested landing points, in playing order (SL-CD-02): two on a par 5 (tee shot and layup), one
    /// on every other hole.
    let approachShots: [Coordinate]

    var id: Int { number }

    enum CodingKeys: String, CodingKey {
        case number, par, yardage, handicapFront, handicapBack, greenCoordinates, teeBoxes, approachShots
    }

    init(number: Int, par: Int, yardage: [Tee: Int], handicapFront: Int, handicapBack: Int,
         greenCoordinates: GreenCoordinates, teeBoxes: TeeBoxes, approachShots: [Coordinate]) {
        self.number = number
        self.par = par
        self.yardage = yardage
        self.handicapFront = handicapFront
        self.handicapBack = handicapBack
        self.greenCoordinates = greenCoordinates
        self.teeBoxes = teeBoxes
        self.approachShots = approachShots
    }

    /// Decodes a hole and checks its shot-line data: a box for every tee and as many approach shots as its par
    /// needs. Either missing throws a `CourseDataError` naming the hole.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let number = try c.decode(Int.self, forKey: .number)
        let par = try c.decode(Int.self, forKey: .par)
        let boxes = try c.decodeIfPresent([Tee: Coordinate].self, forKey: .teeBoxes) ?? [:]
        func box(_ tee: Tee) throws -> Coordinate {
            guard let box = boxes[tee] else { throw CourseDataError.missingTeeBox(hole: number, tee: tee) }
            return box
        }
        let teeBoxes = TeeBoxes(blue: try box(.blue), white: try box(.white), yellow: try box(.yellow), red: try box(.red))
        let approach = try c.decodeIfPresent([Coordinate].self, forKey: .approachShots) ?? []
        guard approach.count == Self.approachShotCount(par: par) else {
            throw CourseDataError.approachShotCount(hole: number, par: par, found: approach.count)
        }
        self.init(number: number, par: par, yardage: try c.decode([Tee: Int].self, forKey: .yardage),
                  handicapFront: try c.decode(Int.self, forKey: .handicapFront),
                  handicapBack: try c.decode(Int.self, forKey: .handicapBack),
                  greenCoordinates: try c.decode(GreenCoordinates.self, forKey: .greenCoordinates),
                  teeBoxes: teeBoxes,
                  approachShots: approach)
    }

    /// How many approach shots a hole of this par has (SL-CD-02): two on a par 5, one otherwise.
    static func approachShotCount(par: Int) -> Int { par == 5 ? 2 : 1 }

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

    /// Whether the course has local rules; without them Settings hides the row (LR-DT-04).
    var hasRules: Bool { !localRules.isEmpty }

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
