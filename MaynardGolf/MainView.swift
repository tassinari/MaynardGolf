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
            Text("Player view TBA")
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
    @Query(sort: [SortDescriptor(\Round.date, order: .reverse)]) var rounds : [Round]
    @Query var players : [Player]
    @State var newGame : Bool = false
    @State var roundInProgress : Round? = nil
    @State var navigationpath  =  NavigationPath()
    var body: some View {
        NavigationStack(path: $navigationpath){
            
            VStack{
                List(){
                    Section {
                        ForEach(players){player in
                            PlayerTileView(player: player)
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
                    Section{
                        ForEach(rounds){ round in
                            NavigationLink(value: NavDestinations.roundView(round), label: {
                                HStack {
                                    Text(round.formattedNames)
                                    Spacer()
                                    Text(round.formattedDate)
                                }
                                .foregroundColor(.black)
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
    

}

#Preview {
    MainView().modelContainer(MainPreviewData.previewContainer)
    
}
