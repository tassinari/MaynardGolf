//
//  MaynardGolfApp.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/9/24.
//

import SwiftUI
import SwiftData

@main
struct MaynardGolfApp: App {
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Player.self,
            Round.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
       
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(Self.sharedModelContainer)
    }
    
    
}

//MARK: Simulator data
///Way to make people & rounds quickly for sim.  Need to call from somewhere...
//TODO: if def out of app store.
extension MaynardGolfApp {
    
    private func addData() {
        Task{ @MainActor in
            
            let context = MaynardGolfApp.sharedModelContainer.mainContext
            var people = try context.fetch(FetchDescriptor<Player>())
            if people.isEmpty {
                makePeople(context: context)
                people = try context.fetch(FetchDescriptor<Player>())
            }
            for i in 1...100 {
                let count = Int.random(in: 1...3)
                let foursome = Array(people.shuffled()[0...count])
                let persons = foursome.map({PersonRound(player: $0, score: Self.scores())})
                let round = Round(players: persons, date: .now.addingTimeInterval(Double(i) * 60.0 * 60.0 * -1.0), course: "MaynardGC")
                context.insert(round)
            }
            
        }
    }
    private func makePeople(context : ModelContext) {
       
        let context = MaynardGolfApp.sharedModelContainer.mainContext
        let names = [("Mark", "Tassinari"), ("Phil", "Mickelson"), ("Nancy", "Tassinari"),("William", "Tassinari"),("Henry", "Tassinari")]
        var people : [Player] = []
        for name in names{
            let player = Player(firstName: name.0, lastName: name.1, color: .blue, photoPath: nil, scale: 1.0, offset: .zero)
            people.append(player)
            context.insert(player)
        }
        try? context.save()
       
    }
    //Non prod, can crash
    private static func scores(_ holes : Int = 9) -> [Score]{
        guard let course = try? Round.courseData(forCourse: "MaynardGC") else{
            fatalError()
        }
        var scores : [Score] = []
        for i in 1...9{
            let hole = course.holes[i - 1]
            scores.append(Score(hole:hole, score: Int.random(in: 3..<9)))
        }
        return scores
    }
}


