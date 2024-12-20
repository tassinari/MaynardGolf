//
//  DataModel.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/9/24.
//

import Foundation
import SwiftData

enum DataError : Error{
    case noCourseData, holeNotFound
}

@Model
class Round : Identifiable, Equatable, Hashable{
    
    static func == (lhs: Round, rhs: Round) -> Bool {
        lhs.id == rhs.id
    }
    @Attribute(.unique) var id : String
   
    internal init(players: [PersonRound], date: Date, course: String) {
        self.players = players
        self.date = date
        self.courseID = course
        self.deleted = false
        self.complete = true
        self.id = UUID().uuidString
        self.weatherTemp = nil
        self.weatherString = nil
        Task{
            self.weatherTemp = try await WeatherReporter.shared.temperature
            self.weatherString = try await WeatherReporter.shared.icon
        }
    }
    
    var players : [PersonRound]
    var date : Date
    var courseID : String
    var deleted : Bool
    var complete : Bool
    var weatherTemp: String?
    var weatherString: String?
    
    @Transient var allPlayersIds : [UUID] {
        return players.map(\.player.id)
    }
   
    var coursData : Course{
        get throws {
            return try Round.courseData(forCourse: courseID)
        }
       
    }
   
    static func courseData(forCourse: String) throws -> Course{
        let bundle = Bundle(for: Player.self )
        guard let path = bundle.url(forResource: forCourse, withExtension: "json") else {
            throw DataError.noCourseData
        }
        let data = try Data(contentsOf: path)
        let course = try JSONDecoder().decode( Course.self, from: data)
        let sorted = course.holes.sorted { h1, h2 in
            return h1.number < h2.number
        }
        return Course(holes: sorted, name:  course.name, slope: course.slope, rating: course.rating)
    }
    var nextHole : Int{
        self.players.reduce(9) { partialResult, pr in
            if let minHole = pr.score.first(where: { sc in
                sc.score == nil
            }){
                return min(partialResult, minHole.hole.number)
            }
            else{
                return partialResult
            }
        }
    }
    var scoresFilledIn : Bool{
        let straglers = self.players.filter { pr in
            pr.score.compactMap({$0.score}).count != 9
        }
        return straglers.isEmpty
    }
    
}
extension Round{
    var inProgress : Bool{
        let today = Calendar.current.isDateInToday(self.date)
       
        return today && !scoresFilledIn
    }
    var cardOrder : [PersonRound]{
        return players.sorted { p1, p2 in
            return p1.cardPosition < p2.cardPosition
        }
    }
    var sortedPlayers : [PersonRound]{
        return players.sorted { p1, p2 in
            return p1.score.compactMap({$0.score}).reduce(0,+) < p2.score.compactMap({$0.score}).reduce(0,+)
        }
    }
    var formattedDate : String{
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    var formattedTime : String{
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    var formattedDateWithTime : String{
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a E MMM d, yyyy"
        return formatter.string(from: date)
    }
}


struct Score : Codable, Hashable, Identifiable{
    var id: Int{
        return hole.number
    }
    
    static func == (lhs: Score, rhs: Score) -> Bool {
        return lhs.hole == rhs.hole && lhs.score == rhs.score
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(score)
        hasher.combine(hole)
    }
    var scoreString : String {
        if let s = score{
            if s == 0{
                return "-"
            }
            return String(s)
        }
        return "-"
    }
    let hole : Hole
    let score : Int?
}
enum Tee : Int, Codable{
    case white, yellow, blue, red
    
    var name : String{
        switch self{
        case .white: return "White"
        case .yellow: return "Yellow"
        case .blue: return "Blue"
        case .red: return "Red"
        }
    }
}
@Model
class PersonRound : Identifiable, Codable{
    
    private enum CodingKeys : CodingKey{
        case player, score, tee_int, cardPosition, id
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        player = try container.decode(Player.self, forKey: .player)
        score = try container.decode([Score].self, forKey: .score)
        tee_int = try container.decode(Int.self, forKey: .tee_int)
        cardPosition = try container.decode(Int.self, forKey: .cardPosition)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(player, forKey: .player)
        try container.encode(score, forKey: .score)
        try container.encode(tee_int, forKey: .tee_int)
        try container.encode(cardPosition, forKey: .cardPosition)
    }
    
    internal init(player: Player, score: [Score], tee: Tee, position : Int) {
        self.player = player
        self.score = score
        self.id = UUID().uuidString
        self.tee_int = tee.rawValue
        cardPosition = position
    }
    @Attribute(.unique) var id : String
    var player : Player
    var score : [Score]
    var tee_int : Int
    var cardPosition : Int
    @Transient var tee : Tee {
        get{
            return Tee(rawValue: tee_int) ?? .white
        }
        set{
            tee_int = newValue.rawValue
        }
    }
    
    var overUnderAttributted : AttributedString{
        let total = overUnderInt
        if total == 0{
            var atr = AttributedString("E")
            atr.font = .callout
            return atr
        }
        var prefix = total > 0 ?  AttributedString("+"):  AttributedString("-")
        prefix.font = .caption2
        prefix.baselineOffset = 5.0
        var str = AttributedString(String(abs(total)))
        str.font = .callout
        return prefix + str
    }
    private var overUnderInt : Int{
       return score.reduce(0) { partialResult, data in
            var working = partialResult
            let par = data.hole.par
            if let s = data.score, s != 0{
                working += (s - par)
            }
            return working
        }
    }
    var overUnderString : String{
        let total = overUnderInt
        
        if total == 0{
            return "E"
        }
        let prefix = total > 0 ? "+" : ""
        return prefix + String(total)
    }
    var totalScore : Int{
        return score.compactMap(\.score).reduce(0,+)
    }
    func scoreInt( hole: Hole) -> Int{
        guard let score = self.score.first(where: { $0.hole == hole })?.score else{
            return 0
        }
        return score
    }
    func scoreString( hole: Hole) -> String{
        guard let score = self.score.first(where: { $0.hole == hole })?.score else{
            return "-"
        }
        return String(score)
    }
    
}


