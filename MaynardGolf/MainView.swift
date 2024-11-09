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
    case deletedRounds
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
        case .deletedRounds:
            DeleteRoundView()
//        case .newGame(let roundBinding):
//           Text("TBI")
//           NewGameView( roundBinding)
        }
    }
}

struct MainView: View {
    @State var scrolling : Bool = false
    @State var settings : Bool = false
    @Bindable var model : MainViewModel = MainViewModel()
    var body: some View {
        NavigationStack(path: $model.navigationpath){
            
            GeometryReader(){ geo in
                List(){
                    Section{
                        ZStack(alignment: .bottom){
                            Image("header")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                               
                            HStack{
                               
                                Text("Maynard Golf")
                                    .font(.largeTitle)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding()
                                Spacer()
                            }
                        
                           
                        }
                       
                    }
                    .listRowInsets(EdgeInsets(top: geo.frame(in: .global).origin.y * -1, leading: 0, bottom: 0, trailing: 0))
                    .edgesIgnoringSafeArea(.top)
                    
                    switch model.viewState {
                    case .loading:
                        Section{
                            HStack{
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        }
                    case .ready:
                        if !model.roundsInProgress.isEmpty{
                            Section {
                                ForEach(model.roundsInProgress){ round in
                                    
                                    ZStack{
                                        RoundCellView(round: round)
                                            .padding()
                                        
                                        NavigationLink(value: NavDestinations.roundView(round)){
                                            
                                        }
                                        .opacity(0)
                                    }
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                    .background(.yellow.opacity(0.08))
                                }
                            }
                            header: {
                                HStack{
                                    Text("In Progress")
                                        .foregroundStyle(.orange)
                                    Spacer()
                                }
                              
                                .padding(.top, 5)
                                .padding(.bottom, 10)
                                .padding([ .leading, .trailing] )
                                
                                
                            }
                        }
                        Section {
                            ForEach(model.players){player in
                                ZStack{
                                    PlayerTileView(model: PlayerTileViewModel(player: player))
                                    NavigationLink(value: NavDestinations.playerView(player)) {
                                        
                                    }
                                    .opacity(0)
                                }
                                
                               
                            }
                        }
                        header: {
                            HStack{
                                Text("Recent Players")
                                Spacer()
                                Button {
                                    model.navigationpath.append(NavDestinations.allPlayers)
                                } label: {
                                    Text("All Players")
                                        .font(.callout)
                                }
                            }
                            .padding(.top, 5)
                            .padding(.bottom, 10)
                            .padding([ .leading, .trailing] )
                        }
                        .listRowSeparator(.hidden)
                        Section{
                            ForEach(model.rounds){ round in
                                NavigationLink(value: NavDestinations.roundView(round), label: {
                                    RoundCellView(round: round)
                                })
                                
                               // .padding([.top, .leading, .trailing], 12)
                            }
                        }
                        header: {
                            HStack{
                                Text("Recent Rounds")
                                Spacer()
                                Button {
                                    model.navigationpath.append(NavDestinations.allRounds)
                                } label: {
                                    Text("All Rounds")
                                        .font(.callout)
                                }

                            }
                            .padding(.top, 5)
                            .padding(.bottom, 10)
                            .padding([ .leading, .trailing] )
                        }
                    }
                    
                   
                }
                .onScrollGeometryChange(for: Double.self) { geo in
                                geo.contentOffset.y
                            } action: { oldValue, newValue in
                                if newValue > (-1 * geo.frame(in: .global).origin.y){
                                    scrolling = true
                                }else{
                                    scrolling = false
                                }
                                
                            }
            }
            .navigationDestination(for: NavDestinations.self) { selection in
                selection.makeView()
            }
           
            .navigationDestination(isPresented: $model.newGame, destination: {
                NewGameView(newround: $model.roundInProgress)
            })
            .onAppear{
                model.refresh()
            }
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        settings = true
                        
                    } label: {
                        Image(systemName: "gearshape")
                    }
                        .tint(scrolling ? .blue : .white)
                    
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Round") {
                        model.newGame = true
                    }
                    .tint(scrolling ? .blue : .white)
                   
                }
            }
           
        }
        .fullScreenCover(isPresented: $settings) {
            SettingsView()
        }
        .fullScreenCover(item: $model.roundInProgress) { round in
            if let model = try? HoleViewContainerModel(round: round){
                HoleViewContainer(model: model)
            }else{
                Text("Error")
            }
            
        }
        
    }
    

}
#if DEBUG
#Preview {
    MainView().modelContainer(MainPreviewData.previewContainer)
    
}
#endif
