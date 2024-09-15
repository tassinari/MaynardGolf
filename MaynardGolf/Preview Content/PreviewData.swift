//
//  PreviewData.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/12/24.
//

import Foundation
import SwiftData
@MainActor
class MainPreviewData {
    private static func scores(_ holes : Int = 9) -> [Score]{
        var scores : [Score] = []
        for i in 1...9{
            scores.append(Score(hole: Hole(number: i, par: 4, yardage: Yardage(red: 385, yellow: 375, white: 365, blue: 345), handicap: i), score: Int.random(in: 3..<7)))
        }
        return scores
    }
    
    static let previewContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Round.self, configurations: config)
            let names = ["Mark", "Nancy"]
            var people : [Player] = []
            for name in names{
                let player = Player(name: name)
                people.append(player)
                container.mainContext.insert(player)
            }
            
            for i in 1...9 {
                let persons = [
                    PersonRound(player: people[0], score: scores()),
                    PersonRound(player: people[1], score: scores())
                ]
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
            let p = ["Mark","Nancy","Henry","Will"]
            for name in p{
                let pl = Player(name: name)
                container.mainContext.insert(pl)
                
            }
            try? container.mainContext.save()
            return container
        } catch {
            fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
        }
    }()
  
}

