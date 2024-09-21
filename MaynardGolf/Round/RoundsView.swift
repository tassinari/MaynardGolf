//
//  RoundsView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/20/24.
//

import SwiftUI
import SwiftData

struct RoundsView: View {
    @State var search: String = ""
    @Query(sort: [SortDescriptor(\Round.date, order: .reverse)]) var rounds : [Round]
    var body: some View {
        VStack{
            List(){
                ForEach(rounds){ round in
                    NavigationLink(value: NavDestinations.roundView(round), label: {
                        HStack {
                            Text(round.formattedNames)
                            Spacer()
                            Text(round.formattedDate)
                        }
                        .foregroundColor(.black)
                    })
                }
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
