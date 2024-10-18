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
    case loading, ready
}

@Observable class MainViewModel {
    var rounds : [Round] = []
    var players : [Player] = []
    var newGame : Bool = false
    var roundInProgress : Round? = nil
    var viewState : ViewState = .loading
  
    var navigationpath : NavigationPath = NavigationPath()
    
    init() {
        Task{ @MainActor in
            let context = MaynardGolfApp.sharedModelContainer.mainContext
            defer {
                self.viewState = .ready
            }
            do{
                self.rounds = try context.fetch(MainViewModel.roundDescriptor)
                self.players = try context.fetch(MainViewModel.playerDescriptor)
            }catch{
                print(error)
            }
        }
    }
    private static var roundDescriptor: FetchDescriptor<Round> {
        var descriptor = FetchDescriptor<Round>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 10
        return descriptor
    }
    private  static var playerDescriptor: FetchDescriptor<Player> {
        var descriptor = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.lastName)])
        descriptor.fetchLimit = 3
        return descriptor
    }
    
}
