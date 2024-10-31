//
//  DeleteRoundView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/30/24.
//

import SwiftUI
import SwiftData

struct DeleteRoundView: View {
    @State var showingAlert : Bool = false
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Round> { rnd in
        rnd.deleted == true
    }, sort: [SortDescriptor(\Round.date, order: .reverse)] ) private var rounds: [Round]
    var body: some View {
        
            VStack{
                if rounds.isEmpty {
                    ContentUnavailableView {
                        Label("No Deleted Rounds", systemImage: "trash")
                    } description: {
                        Text("Deleted rounds will appear here.")
                    }
                }else{
                    List(){
                        ForEach(rounds){ round in
                            RoundCellView(round: round)
                                .swipeActions(allowsFullSwipe: false) {
                                    Button {
                                        withAnimation {
                                            round.deleted = false
                                            try? context.save()
                                        }
                                    } label: {
                                        Label("Restore", systemImage: "arrow.up.trash")
                                    }
                                    .tint(.green)
                                    
                                    Button(role: .destructive) {
                                        withAnimation {
                                            context.delete(round)
                                            try? context.save()
                                        }
                                       
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                }
                        }
                        
                    }
                    .navigationTitle("Trash")
                    .toolbar {
                        if rounds.count > 0 {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    showingAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                
                            }
                        }
                    }
                    .alert(isPresented:$showingAlert) {
                        Alert(
                            title: Text("Permenantly Delete?"),
                            message: Text("This will empty your trash."),
                            primaryButton: .destructive(Text("Delete")) {
                                for r in rounds {
                                    context.delete(r)
                                    try? context.save()
                                }
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                
            }
    }
}

#Preview {
    DeleteRoundView()
}
