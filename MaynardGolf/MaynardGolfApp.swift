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
//            HoleView(model: HoleView.ViewModel(scores:
//                                                [
//                                                  HoleView.HoleScore(name: "Mark", score: 4),
//                                                  HoleView.HoleScore(name: "Nancy", score: 5),
//                                                  HoleView.HoleScore(name: "Henry", score: 5),
//                                                  HoleView.HoleScore(name: "Will", score: 5)
//                                                ]
//                                                ))
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
