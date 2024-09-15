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
class Player{
    internal init(name: String) {
        self.name = name
    }
    @Attribute(.unique) var name : String
    var rounds : [PersonRound]?
}

@Model
class PersonRound : Identifiable{
    internal init(player: Player, score: [Score]) {
        self.player = player
        self.score = score
    }
    var id : String{
        return player.name + score.reduce("", { partialResult, sc in
            return partialResult + (sc.score != nil ? String(sc.score!) : "-")
        })
    }
    
    var player : Player
    var score : [Score]
    
}
@Model
class Round{
    internal init(players: [PersonRound], date: Date, course: String) {
        self.players = players
        self.date = date
        self.courseID = course
    }
    
    var players : [PersonRound]
    var date : Date
    var courseID : String
    
    var formattedDate : String{
        let formatter = DateFormatter()
        formatter.dateStyle = .short
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
    var coursData : [Hole]{ 
        get throws {
            return try Round.courseData(forCourse: courseID)
        }
       
    }
   
    static func courseData(forCourse: String) throws -> [Hole]{
        let bundle = Bundle(for: Player.self )
        guard let path = bundle.url(forResource: forCourse, withExtension: "json") else {
            throw DataError.noCourseData
        }
        let data = try Data(contentsOf: path)
        let course = try JSONDecoder().decode( Course.self, from: data)
        return course.holes.sorted { h1, h2 in
            return h1.number < h2.number
        }
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
            return String(s)
        }
        return " "
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
    
}
struct Hole : Codable, Equatable, Hashable{
    static func == (lhs: Hole, rhs: Hole) -> Bool {
        return lhs.number == rhs.number
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
    var holeIcon : URL?
    var number : Int
    var par : Int
    var yardage : Yardage
    var handicap : Int
      
}

