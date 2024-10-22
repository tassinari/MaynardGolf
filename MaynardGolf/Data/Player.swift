//
//  PLAYER.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/20/24.
//

import Foundation
import SwiftData

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
    @Transient var scoreDistribution : [ScoreName : Int]? {
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
                    var values : [ScoreName : Int] = [:]
                    for pr in thisPersonsRounds{
                        for score in pr.score {
                            if let sc = score.score{
                                let result = ScoreName.name(par: score.hole.par, score: sc)
                                if let num = values[result]{
                                    values[result] = num + 1
                                }else{
                                    values[result] = 1
                                }
                                
                            }
                           
                        }
                    }
                    return values
                }catch{
                    return nil
                }
            }
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

enum Trend {
    case up
    case down
}

extension Player {
    @MainActor
    func trend(for currentScore : Int, round: Round) -> Trend? {
        let lastLimit : Int = 5
            do{
                guard let context = self.modelContext else {
                    return nil
                }
                var descriptor = FetchDescriptor<Round>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                let playerID = self.id
                let date = round.date
                descriptor.predicate = #Predicate{ round in
                    return  round.date < date && round.complete == true && round.deleted == false && round.players.contains(where: { $0.player.id == playerID })
                    
                }
                descriptor.fetchLimit = lastLimit
               // let context = MaynardGolfApp.sharedModelContainer.mainContext
                let recent = try context.fetch<Round>(descriptor)
                //Pull this person from each round
                let thisPersonsRounds : [PersonRound] = recent.compactMap{ r in
                    return r.players.first(where: {$0.player == self})
                }
                if thisPersonsRounds.isEmpty {
                    return nil
                }
                let scores : [Int] = thisPersonsRounds.map{$0.totalScore}
                let avg = Double(scores.reduce(0, +)) / Double(thisPersonsRounds.count)
                
                return avg >= Double(currentScore) ? .down : .up
            }catch{
                return nil
            }
        }
}
