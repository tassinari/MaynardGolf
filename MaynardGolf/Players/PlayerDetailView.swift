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
                round.deleted == false && round.allPlayersIds.contains(id)
            })
         }
        Task{
            if let dist = await player.scoreDistribution{
                scoreDistribution = dist
            }
            handicap = await player.handicap
            let data = await player.maxMinScores
            min = data?.1
            max = data?.0
            avg = data?.2
        }
    }
    var scoreDistribution : [ScoreName : Int] = [:]
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
                    VStack(alignment: .leading){
                        HStack{
                            PlayerImage(imageRadius: 100.0,player: model.player)
                            VStack(alignment: .leading){
                                Text(model.player.name)
                                    .font(.largeTitle)
                                if let hc = model.handicap{
                                    HStack{
                                        Text("Handicap")
                                            .font(.callout)
                                            .fontWeight(.thin)
                                        Text( String(format: "%.1f", hc))
                                    }
                                }
                            }
                            .padding([.leading])
                            
                        }
                        HStack{
                            SideHistogram(model: SideHistogramViewModel(rawScores: model.scoreDistribution))
                          //  Color.blue
                                
                            Spacer()
                            VStack(alignment: .center){
                                if let min = model.min, let max = model.max , let avg = model.avg{
                                    VStack{
                                        Text("Best")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                        Text(String(min))
                                            .font(.callout)
                                    }
                                    VStack{
                                        Text("Worst")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                        Text(String(max))
                                            .font(.callout)
                                    }
                                    VStack{
                                        Text("Average")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        Text(String(format: "%.1f", avg))
                                            .font(.callout)
                                    }
                                }
                               
                            }
                        }
                        .padding([.top])
                        .padding([.leading],45)
                        
                        
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
