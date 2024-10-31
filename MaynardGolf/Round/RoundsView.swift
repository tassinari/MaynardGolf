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
    @Query(filter: #Predicate<Round> { rnd in
        rnd.deleted == false
    }, sort: [SortDescriptor(\Round.date, order: .reverse)] ) private var rounds: [Round]
    var body: some View {
        VStack{
            List(){
                ForEach(filteredNames){ round in
                    NavigationLink(value: NavDestinations.roundView(round), label: {
                        RoundCellView(round: round)
                    })
                }
                .onDelete { indexes in
                    for i in indexes {
                        let round = self.rounds[i]
                        round.deleted = true
                        try? context.save()
                    }
                    
                }
            }
            .toolbar {
                NavigationLink(value: NavDestinations.deletedRounds, label: {
                   Text("Deleted")
                })
               
            }
        }
        
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
    

}

#Preview {
    NavigationStack {
        RoundsView().modelContainer(MainPreviewData.previewContainer)
    }
    
}
