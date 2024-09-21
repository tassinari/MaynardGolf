//
//  PlayersView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/20/24.
//

import SwiftUI
import SwiftData

struct PlayersView: View {
    @State var search: String = ""
    @Query() var players : [Player]
    var body: some View {
        VStack{
            List(){
                ForEach(players){ player in
                    NavigationLink(value: NavDestinations.playerView(player)) {
                        PlayerTileView(player: player)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Players")
        .searchable(text: $search)
        
    }
    var filteredNames : [Player]{
        if search.isEmpty { return players}
        return players.filter { player in
            let names = players.map({$0.name})
            return names.contains(where: {$0.localizedStandardContains(search)})
        }
    }
}

#Preview {
    NavigationStack {
        PlayersView().modelContainer(MainPreviewData.previewContainer)
    }
}
