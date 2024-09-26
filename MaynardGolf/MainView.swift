//
//  MainView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/12/24.
//

import SwiftUI
import SwiftData

enum NavDestinations : Hashable {
    
    case roundView(Round)
    case playerView(Player)
    case allPlayers
    case allRounds
   // case newGame(Binding<Round?>)
    
    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .roundView(let round):
            if let model = try? RoundDetailModel(round: round){
                RoundDetailView(model: model)
            }else{
                //FIXME: use standard error view
                Text("Error")
            }
        case .playerView(let player):
            PlayerDetailView(model: PlayerDetailModel(player: player))
        case .allPlayers:
            PlayersView()
        case .allRounds:
            RoundsView()
//        case .newGame(let roundBinding):
//           Text("TBI")
//           NewGameView( roundBinding)
        }
    }
}

struct MainView: View {
    @Query(roundDescriptor) var rounds : [Round]
    @Query(playerDescriptor) var players : [Player]
    @State var newGame : Bool = false
    @State var roundInProgress : Round? = nil
    @State var navigationpath  =  NavigationPath()
    var body: some View {
        NavigationStack(path: $navigationpath){
            
            VStack{
                List(){
                    Section {
                        ForEach(players){player in
                            ZStack{
                                PlayerTileView(player: player)
                                NavigationLink(value: NavDestinations.playerView(player)) {
                                    
                                }
                                .opacity(0)
                            }
                            
                           
                        }
                    }
                    header: {
                        HStack{
                            Text("Top Players")
                            Spacer()
                            Button {
                                navigationpath.append(NavDestinations.allPlayers)
                            } label: {
                                Text("All Players")
                                    .font(.callout)
                            }

                        }
                        .padding( )
                    }
            
                    .listRowSeparator(.hidden)
                    Section{
                        ForEach(rounds){ round in
                            NavigationLink(value: NavDestinations.roundView(round), label: {
                                RoundCellView(round: round)
                            })
                            
                            .padding([.top, .leading, .trailing], 12)
                        }
                    }
                    header: {
                        HStack{
                            Text("Recent Rounds")
                            Spacer()
                            Button {
                                navigationpath.append(NavDestinations.allRounds)
                            } label: {
                                Text("All Rounds")
                                    .font(.callout)
                            }

                        }
                        .padding( )
                    }
                    
                   
                }
                
               
            }
            .navigationDestination(for: NavDestinations.self) { selection in
                selection.makeView()
            }
            .navigationTitle("Maynard Golf")
            .navigationDestination(isPresented: $newGame, destination: {
                NewGameView(newround: $roundInProgress)
            })
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        
                    } label: {
                        Image(systemName: "gearshape")
                    }

                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Round") {
                        newGame = true
                    }
                }
            }
        }
        .fullScreenCover(item: $roundInProgress) { round in
            HoleViewContainer(model: HoleViewContainerModel(round: round))
        }
        
    }
    static var roundDescriptor: FetchDescriptor<Round> {
        var descriptor = FetchDescriptor<Round>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 3
        return descriptor
    }
    static var playerDescriptor: FetchDescriptor<Player> {
        var descriptor = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.lastName, order: .reverse)])
        descriptor.fetchLimit = 3
        return descriptor
    }

}

#Preview {
    MainView().modelContainer(MainPreviewData.previewContainer)
    
}
