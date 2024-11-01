//
//  PlayersView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/20/24.
//

import SwiftUI
import SwiftData

struct PlayersView: View {
    @State private var deleteIndices : IndexSet? = nil
    @Environment(\.modelContext) private var context
    @State var search: String = ""
    @State var add: Bool = false
    @Query() var players : [Player]
    @State var confirmDelete: Bool = false
    var body: some View {
        VStack{
            List(){
                ForEach(filteredNames){ player in
                    NavigationLink(value: NavDestinations.playerView(player)) {
                        PlayerTileView(model: PlayerTileViewModel(player: player))
                    }
                }
                .onDelete(perform: confirmDelete)
            }
            
        }
        .confirmationDialog("Confirm Delete", isPresented: $confirmDelete, actions: {
            Button("Delete", role: .destructive) {
                withAnimation {
                    deletePlayer()
                }
            }
        }, message: {
            Text("Are you sure you want to delete this Player?  This cannot be undone")
        })
       
        .toolbar(content: {
            Button {
                add = true
            } label: {
                Text("Add")
            }

        })
        .listStyle(.plain)
        .navigationTitle("Players")
        .searchable(text: $search)
        .fullScreenCover(isPresented: $add, content: {
            PlayerEntryView()
                
        })
        
    }
    var filteredNames : [Player]{
        if search.isEmpty { return players}
        return players.filter { player in
            let names = players.map({$0.name})
            return names.contains(where: {$0.localizedStandardContains(search)})
        }
    }
    func confirmDelete(index : IndexSet){
        deleteIndices = index
        confirmDelete = true
    }
    func deletePlayer(){
        guard let deleteIndices else { return }
        for i in deleteIndices{
            let p = players[i]
            context.delete(p)
            try? context.save()
        }
        
    }
}
#if DEBUG
#Preview {
    NavigationStack {
        PlayersView().modelContainer(MainPreviewData.previewContainer)
    }
}
#endif
