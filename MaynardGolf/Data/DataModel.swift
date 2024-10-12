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
enum ColorValues : Int32 {
    case red, blue, green, yellow, orange
}

@Model
class Player : Identifiable, Equatable, Hashable{
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
    }
    init( firstName: String, lastName: String, color: ColorValues, photoPath : String?, scale: CGFloat = 0, offset: CGSize = .zero) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.photoPath = photoPath
        self.color_int = color.rawValue
        self.offsetX = offset.width
        self.offsetY = offset.height
        self.scale = scale
    }

    @Attribute(.unique) var id : UUID
    var firstName : String
    var lastName : String
    var photoPath : String?
    private var color_int : Int32
    private var offsetX : CGFloat
    private var offsetY : CGFloat
    var scale : CGFloat
    
    @Transient var name : String{
        return firstName + " " + lastName
    }
    var rounds : [PersonRound]?
    
    @Transient var offset : CGSize{
        get{
            return CGSize(width: offsetX, height: offsetY)
        }
        set{
            self.offsetX = newValue.width
            self.offsetY = newValue.height
        }
    }
    @Transient var color : ColorValues{
        get{
            return ColorValues(rawValue: color_int)!
        }
        set{
            self.color_int = newValue.rawValue
        }
        
    }
    
    @Transient var maxMinScores : (Int,Int, Double)?{
        get async{
            await MainActor.run{
                do{
                    guard let context = self.modelContext else {
                        return nil
                    }
                   // let context = MaynardGolfApp.sharedModelContainer.mainContext
                    let lastTwenty = try context.fetch<Round>(roundDescriptor)
                    //Pull this person from each round
                    let thisPersonsRounds : [PersonRound] = lastTwenty.compactMap{ r in
                        return r.players.first(where: {$0.player == self})
                    }
                    let scores : [Int] = thisPersonsRounds.map{$0.totalScore}
                    let max = scores.max()
                    let min = scores.min()
                    let avg = Double(scores.reduce(0, +)) / Double(thisPersonsRounds.count)
                    if let max, let min{
                        return (max,min, avg)
                    }
                    return nil
                }catch{
                    return nil
                }
            }
        }
       
    }
    
}

@Model
class PersonRound : Identifiable{
    internal init(player: Player, score: [Score]) {
        self.player = player
        self.score = score
        self.id = UUID().uuidString
    }
    @Attribute(.unique) var id : String
    var player : Player
    var score : [Score]
    
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
        
        self.id = UUID().uuidString
    }
    
    var players : [PersonRound]
    var date : Date
    var courseID : String
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
    var complete : Bool{
        let straglers = self.players.filter { pr in
            pr.score.compactMap({$0.score}).count != 9
        }
        return straglers.isEmpty
    }
    
}
extension Round{
    var sortedPlayers : [PersonRound]{
        return players.sorted { p1, p2 in
            return p1.score.compactMap({$0.score}).reduce(0,+) < p2.score.compactMap({$0.score}).reduce(0,+)
        }
    }
    var formattedDate : String{
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    var formattedDateWithTime : String{
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a E MMM d, yyyy"
        return formatter.string(from: date)
    }
    var formattedNames : String{
        var names : String = ""
        for (i,pRound) in players.enumerated(){
            if i == players.count - 1{
                names.append(pRound.player.name)
            }else{
                names.append(pRound.player.name + ", ")
            }
            
        }
        return names
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
struct Yardage : Codable{
    let red : Int
    let yellow : Int
    let white : Int
    let blue : Int
}
struct Course : Codable{
    var holes : [Hole]
    var name : String
    var slope : Double
    var rating : Double
    
    var par : Int{
        return holes.reduce(0){ $0 + $1.par }
    }
    var parFront : Int{
        return Array(holes[0...8]).reduce(0){ $0 + $1.par }
    }
    var parBack : Int{
        return Array(holes[9...17]).reduce(0){ $0 + $1.par }
    }
    
}
struct Hole : Codable, Equatable, Hashable{
    static func == (lhs: Hole, rhs: Hole) -> Bool {
        return lhs.number == rhs.number
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
    var holeIconName : String
    var number : Int
    var par : Int
    var yardage : Yardage
    var handicap : Int
      
}

