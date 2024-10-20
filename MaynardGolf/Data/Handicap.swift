//
//  Handicap.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/6/24.
//
import SwiftData
import Foundation

extension Player {
    
    //Per USGA best 8 of last 20 score differentials
    //TODO: need safeguards like USGA
    public var handicap: Double? {
        get async{
            
            await MainActor.run{
               
                do{
                    guard let context = self.modelContext else {
                        return nil
                    }
                    let lastTwenty = try context.fetch<Round>(roundDescriptor)
                    
                    //Pull this person from each round
                    let thisPersonsRounds : [PersonRound] = lastTwenty.compactMap{ r in
                        return r.players.first(where: {$0.player == self})
                    }
                    //Sort by this players best score
                    let sorted = thisPersonsRounds.sorted { r1, r2 in
                        return r1.totalScore > r2.totalScore
                    }
                    let rangeMax = min(thisPersonsRounds.count - 1,7)
                    if rangeMax <= 0 || rangeMax >= sorted.count { return nil }
                    let differentials = Array(sorted[0...rangeMax]).map({scoreDifferential(gross: $0.totalScore, numHoles: .nine)})
                    
                    //return average / 2 (since we are pinned to 9 for now)
                    let average = differentials.reduce(0, +) / Double(differentials.count)
                    return average / 2
                    
                }catch{
                    print(error)
                }
                return nil
            }
        }
    }
    private static var slope : Double =  {
        if let course = try? Round.courseData(forCourse: "MaynardGC"){
            return course.slope
        }
        return 125.0 //Fallback, shouldnt hit
    }()
    private static var rating : Double =  {
        if let course = try? Round.courseData(forCourse: "MaynardGC"){
            return course.rating
        }
        return 69.1  //Fallback, shouldnt hit
    }()
    
    //FIXME: todo, figure out gross adjusted
    private func scoreDifferential(gross : Int, numHoles: RoundLength ) -> Double {
    // From USGA:    (113 / Slope Rating) x (Adjusted Gross Score - Course Rating - PCC adjustment)
        var _gross = gross
        //FIXME: 9 hole calculation, there is an expected 18 hoile differential based on current handicap
        //But for now just double...
        if numHoles == .nine{
            _gross *= 2
        }
        
        return (113.0 / Self.slope) * (Double(_gross) - Self.rating - 0)
    }
    
    var roundDescriptor: FetchDescriptor<Round> {
        var descriptor = FetchDescriptor<Round>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let playerID = self.id
        descriptor.predicate = #Predicate{ round in
            return round.complete == true && round.deleted == false && round.players.contains(where: { $0.player.id == playerID })
            
        }
        descriptor.fetchLimit = 20
        return descriptor
    }
}
enum RoundLength {
    case nine, eighteen
}


