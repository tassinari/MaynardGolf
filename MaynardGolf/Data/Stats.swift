//
//  Stats.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/9/24.
//

import Foundation
import SwiftData

extension Player{
    
    var playerHoleStats: [HoleStatsModel] {
        do{
            guard let context = self.modelContext else {
                return []
            }
           // let context = MaynardGolfApp.sharedModelContainer.mainContext
            let lastTwenty = try context.fetch<Round>(roundDescriptor)
            //Pull this person from each round
            let thisPersonsRounds : [PersonRound] = lastTwenty.compactMap{ r in
                return r.players.first(where: {$0.player == self})
            }
            var holeDict : [Hole:[Int]] = [:]
            for round in thisPersonsRounds{
                for score in round.score{
                    if let s = score.score{
                        if holeDict[score.hole] == nil{
                            holeDict[score.hole] = [s]
                        }else{
                            holeDict[score.hole]?.append(s)
                        }
                        
                    }
                   
                }
            }
            return holeDict.keys.compactMap{ key in
                if let d = holeDict[key]{
                    let average = Double(d.reduce(0, +)) / Double(d.count)
                    return  HoleStatsModel(icon: key.holeIconName, scores: d, holeNumber: key.number, par: key.par, average: average, scoreString: Self.scoreName(avg: average, fromPar: key.par))
                }
               return nil
            }.sorted { d1, d2 in
                d1.holeNumber < d2.holeNumber
            }
            
        }catch{
            
        }
        
        return []
    }
    static func scoreName(avg: Double, fromPar: Int) -> ScoreName {
        switch fromPar {
        case 3:
            switch  avg {
            case 0..<1.4:
                return .eagle
            case 1.5..<2.4:
                return .birdie
            case 2.5..<3.4:
                return .par
            case 3.5..<4.4:
                return .bogey
            case 4.5..<5.4:
                return .doubleBogey
            case 5.5..<6.4:
                return .tripleBogey
                
            default:
                return .other
            }
            
        case 4:
            switch  avg {
            case 0..<1.4:
                return .doubleEagle
            case 1.5..<2.4:
                return .eagle
            case 2.5..<3.4:
                return .birdie
            case 3.5..<4.4:
                return .par
            case 4.5..<5.4:
                return .bogey
            case 5.5..<6.4:
                return .doubleBogey
            case 6.5..<7.4:
                return .tripleBogey
                
            default:
                return .other
            }
        case 5:
            switch  avg {
            case 0..<2.4:
                return .doubleEagle
            case 2.5..<3.4:
                return .eagle
            case 3.5..<4.4:
                return .birdie
            case 4.5..<5.4:
                return .par
            case 5.5..<6.4:
                return .bogey
            case 6.5..<7.4:
                return .doubleBogey
            case 7.5..<8.4:
                return .tripleBogey
                
            default:
                return .other
            }
        default:
            return .other
            
        }
    }
}
