//
//  RoundsView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/20/24.
//

import SwiftUI
import SwiftData

struct RoundsView: View {
    @State private var deleteIndices : IndexSet? = nil
    @Environment(\.modelContext) private var context
    @State var search: String = ""
    @State var confirmDelete: Bool = false
    @Query(sort: [SortDescriptor(\Round.date, order: .reverse)]) var rounds : [Round]
    var body: some View {
        VStack{
            List(){
                ForEach(rounds){ round in
                    NavigationLink(value: NavDestinations.roundView(round), label: {
                        RoundCellView(round: round)
                    })
                }
                .onDelete(perform: confirmDelete)
            }
        }
        .confirmationDialog("Confirm Delete", isPresented: $confirmDelete, actions: {
            Button("Delete", role: .destructive) {
                withAnimation {
                    deleteRound()
                }
                
            }
        }, message: {
            Text("Are you sure you want to delete this round?  This cannot be undone")
        })
        
        .navigationTitle("Rounds")
        .searchable(text: $search)
        
    }
    var filteredNames : [Round]{
        if search.isEmpty { return rounds}
        return rounds.filter { round in
            let names = round.players.map({$0.player.name})
            return names.contains(where: {$0.localizedStandardContains(search)})
        }
    }
    func deleteRound(){
        guard let deleteIndices else { return }
        for i in deleteIndices{
            let r = rounds[i]
            context.delete(r)
            try? context.save()
        }
        
    }
    func confirmDelete(index : IndexSet){
        deleteIndices = index
        confirmDelete = true
    }
}

#Preview {
    NavigationStack {
        RoundsView().modelContainer(MainPreviewData.previewContainer)
    }
    
}
