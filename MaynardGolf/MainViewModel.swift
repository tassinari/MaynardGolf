//
//  MainViewModel.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/1/24.
//

import Foundation
import SwiftUI
import SwiftData

enum ViewState{
    case loading, ready, noData
}

@Observable class MainViewModel {
    var rounds : [Round] = []
    var roundsInProgress : [Round] = []
    var players : [Player] = []
    var newGame : Bool = false
    var roundInProgress : Round? = nil
    var viewState : ViewState = .loading
  
    var navigationpath : NavigationPath = NavigationPath()
    
    init() {
        refresh()
        let _ = NotificationCenter.default.addObserver(forName: Notification.Name.didImport, object: nil, queue: nil) { [weak self ] note in
            self?.refresh()
        }
    }
    func refresh(){
        Task{ @MainActor in
            let context = MaynardGolfApp.sharedModelContainer.mainContext
            defer {
                self.viewState = players.isEmpty ? .noData : .ready
            }
            do{
                self.rounds = try context.fetch(MainViewModel.roundDescriptor)
                self.roundsInProgress = self.rounds.filter({$0.inProgress})
                self.players = try context.fetch(MainViewModel.playerDescriptor)
            }catch{
                print(error)
            }
        }
    }
    
    private static var roundDescriptor: FetchDescriptor<Round> {
        var descriptor = FetchDescriptor<Round>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.predicate = #Predicate<Round>{ rnd in
            return rnd.deleted == false
        }
        descriptor.fetchLimit = 10
        return descriptor
    }
    private  static var playerDescriptor: FetchDescriptor<Player> {
        var descriptor = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.lastName)])
        descriptor.fetchLimit = 3
        return descriptor
    }
    
}
