//
//  PlayerDetailView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/21/24.
//
import SwiftData
import SwiftUI

@Observable class PlayerDetailModel: Identifiable {
    internal init(player: Player, container : ModelContainer = MaynardGolfApp.sharedModelContainer) {
        self.player = player
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Round>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let id = player.id
        if let rounds = try? context.fetch(descriptor) {
            self.rounds = rounds.filter({ round in
                round.allPlayersIds.contains(id)
            })
         }
        Task{
            handicap = await player.handicap
            let data = await player.maxMinScores
            min = data?.1
            max = data?.0
            avg = data?.2
        }
    }
   
    var min : Int? = nil
    var max : Int? = nil
    var avg : Double? = nil
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
                    VStack{
                        HStack{
                            PlayerImage(player: model.player)
                            Text(model.player.name)
                                .font(.largeTitle)
                                .padding()
                            
                        }
                        HStack{
                            if let min = model.min, let max = model.max , let avg = model.avg{
                                StatView(stat: String(min), title: "Best")
                                StatView(stat: String(max), title: "Worst")
                                StatView(stat: String(format: "%.1f", avg), title: "Average")
                            }
                            if let hc = model.handicap{
                                StatView(stat: String(format: "%.1f", hc), title: "Handicap")
                            }
                        }
                        .padding()
                    }
                }
                .listRowSeparator(.hidden)
                
                Section("Hole Data"){
                    ForEach(model.player.playerHoleStats){ model in
                        HoleStatsCell(holeStats: model)
                    
                    }
                 
                }
                
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
        PlayerDetailView(model: PlayerDetailModel(player: MainPreviewData.examplePlayer, container: MainPreviewData.previewContainer))
    }
    
}
