//
//  PreviewData.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/12/24.
//

import Foundation
import SwiftData
import SwiftUICore
@MainActor
class MainPreviewData {
    private static func scores(_ holes : Int = 9) -> [Score]{
        guard let course = try? Round.courseData(forCourse: "MaynardGC") else{
            fatalError()
        }
        var scores : [Score] = []
        for i in 1...9{
            scores.append(Score(hole:course.holes[i - 1], score: Int.random(in: 3..<7)))
        }
        return scores
    }
    
    static let previewContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Round.self, configurations: config)
            let names = [("Mark", "Tassinari"), ("Phil", "Mickelson"), ("Nancy", "Tassinari"),("William", "Tassinari"),("Henry", "Tassinari")]
            var people : [Player] = []
            for name in names{
                let player = Player(firstName: name.0, lastName: name.1, color: .red, photoPath: nil, scale: 1.0, offset: .zero)
                people.append(player)
                container.mainContext.insert(player)
            }
            
            for i in 1...20 {
                
                let count = Int.random(in: 1...3)
                let foursome = Array(people.shuffled()[0...count])
                let tee =  Tee(rawValue: Int.random(in: 1...3)) ?? .white
                let persons = foursome.map({PersonRound(player: $0, score: scores(), tee: tee)})
                let round = Round(players: persons, date: .now.addingTimeInterval(Double(i) * 60.0 * 60.0 * -1.0), course: "MaynardGC")
                container.mainContext.insert(round)
            }
            try? container.mainContext.save()
            return container
        } catch {
            fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
        }
    }()
    @MainActor
    static let round : Round? =  {
        if let round = try? previewContainer.mainContext.fetch(FetchDescriptor<Round>()).first{
            return round
        }
        return nil
    }()
    static let examplePlayer : Player = {
        let model = try! previewContainer.mainContext.fetch(FetchDescriptor<Player>()).first!
        return model
    }()
    static let exampleHole : Hole = {
        guard let course = try? Round.courseData(forCourse: "MaynardGC") else{
            fatalError()
        }
        return course.holes.first!
    }()
}

@MainActor
class PlayerPreviewData {
   
    
    static let previewContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Player.self, configurations: config)
            let names = [("Mark", "Tassinari"), ("Phil", "Mickelson"), ("Nancy", "Tassinari"), ("Henry", "Tassinari")]
            for name in names{
                let pl = Player(firstName: name.0, lastName: name.1,color: .red, photoPath: nil, scale: 1.0, offset: .zero)
                container.mainContext.insert(pl)
                
            }
            try? container.mainContext.save()
            return container
        } catch {
            fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
        }
    }()
  
    static let cardPlayerScoreCellModel : CardPlayerScoreCell.ViewModel = {
        let model = CardPlayerScoreCell.ViewModel(player: PlayerPreviewData.examplePlayer, score: String("76"))
        return model
    }()
    static let examplePlayer : Player = {
        let model = try! previewContainer.mainContext.fetch(FetchDescriptor<Player>()).first!
        return model
    }()
    static let somePlayers : [Player] = {
        let model = try! previewContainer.mainContext.fetch(FetchDescriptor<Player>())
        return model
    }()
}

