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
            handicap = await player.handicap
        }
    }
  
    var handicap : Double? = nil
    var player: Player
    var rounds : [Round] = []
}

struct PlayerDetailView: View {
    var model : PlayerDetailModel
    @State var edit : Bool = false
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
                        if let hc = model.handicap{
                            Text(String(format: "%.1f", hc))
                                .foregroundStyle(.white)
                                .frame(width: 45, height: 45)
                                .background(
                                   Circle()
                                    .foregroundColor(Color("green2"))
                                     .padding(4)
                                 )
                        }
                        
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
        .fullScreenCover(isPresented: $edit, content: {
            PlayerEntryView(model: PlayerEntryView.ViewModel(player: model.player))
                
        })
        .toolbar {
            Button {
                edit = true
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
