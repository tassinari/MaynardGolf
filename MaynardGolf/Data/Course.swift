//
//  Course.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/20/24.
//

import Foundation

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
struct Hole : Codable, Equatable, Hashable, Identifiable{
    var id: Int{ return number}
    
    
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
    var greenCoordinates : GreenCoordinates
      
}
struct Coordinate : Codable{
    var lattitude : Double
    var longitude : Double
}
struct GreenCoordinates : Codable {
    var front : Coordinate
    var back : Coordinate
    var center : Coordinate
}
