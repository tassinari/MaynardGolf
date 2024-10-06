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
        var scores : [Score] = []
        for i in 1...9{
            scores.append(Score(hole: Hole(holeIconName: "hole4", number: i, par: 4, yardage: Yardage(red: 385, yellow: 375, white: 365, blue: 345), handicap: i), score: Int.random(in: 3..<7)))
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
            
            for i in 1...9 {
                let persons = people.map({PersonRound(player: $0, score: scores())})
                let round = Round(players: persons, date: .now.addingTimeInterval(Double(i) * 60.0 * 60.0 * -1.0), course: "MaynardGC")
                container.mainContext.insert(round)
            }

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

