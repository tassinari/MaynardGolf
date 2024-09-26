//
//  PlayerDetailView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/21/24.
//
import SwiftData
import SwiftUI

@Observable class PlayerDetailModel: Identifiable {
    internal init(player: Player) {
        self.player = player
        
        let descriptor = FetchDescriptor<Round>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let id = player.id
        Task{
            let context = await ModelContext(MaynardGolfApp.sharedModelContainer)
            self.rounds = try! context.fetch(descriptor).filter({ round in
                round.allPlayersIds.contains(id)
            })
        }
    }
  
    
    var player: Player
    var rounds : [Round] = []
}

struct PlayerDetailView: View {
    var model : PlayerDetailModel
    init(model: PlayerDetailModel) {
        self.model = model
       
    }
    var body: some View {
        VStack{
            List(){
                
                Section(){
                    HStack{
                        PlayerImage(player: model.player)
                        Text(model.player.name)
                            .font(.largeTitle)
                            .padding()
                    }
                 
                }
                .listRowSeparator(.hidden)
                
                Section("Rounds"){
                    ForEach(model.rounds){ round in
                        NavigationLink(value: NavDestinations.roundView(round), label: {
                            RoundCellView(round: round)
                        })
                    }
                 
                }
            }
            .listStyle(.plain)
            
        }
        .toolbar {
            Button {
                
            } label: {
                Text("Edit")
            }

        }
        
    }
    
}

#Preview {
    NavigationStack {
        PlayerDetailView(model: PlayerDetailModel(player: PlayerPreviewData.examplePlayer))
    }
    
}
