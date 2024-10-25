//
//  NewGameView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/13/24.
//

import SwiftUI
import SwiftData

extension NewGameView{
    @Observable class ViewModel{
        let maxPlayers = 4
        var players : [AddPlayerModel] = []
        var ninehole : Bool  = true
        var canAddPlayers : Bool{
            return players.count < maxPlayers
        }
        func addPlayers(_ pl : [AddPlayerModel]){
            for p in pl{
                if canAddPlayers && !players.contains(where: {$0.player == p.player}){
                    players.append(p)
                }
            }
        }
        func delete(at offsets: IndexSet){
            players.remove(atOffsets: offsets)
        }
        func createRound(context: ModelContext) -> Round{
            let courseName = "MaynardGC"
            var prs : [PersonRound] = []
            //FIXME: time bomb force unwrap
            let holes = try! Round.courseData(forCourse: courseName).holes
            for pm in players{
                
                let pr = PersonRound(player: pm.player, score: holes.map{Score(hole:$0, score: nil)}, tee: pm.tee)
                prs.append(pr)
              
            }
            let r = Round(players: prs, date: .now, course: courseName)
            context.insert(r)
            return r
        }
    }
}

struct NewGameView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var context
    @Bindable var model : ViewModel = ViewModel()
    @Binding var newround : Round?
    @State var add : Bool = false
    @Query var allPlayers : [Player]
    var body: some View {
       
        VStack{
            List(){
                Section() {
                    Text("New Round")
                        .font(.largeTitle)
                }
                .listRowSeparator(.hidden)
                
                Section("Players") {
                    ForEach(model.players, id:\.player){ playerModel in
                        AddPlayerCell(model: playerModel)
                    }
                    .onDelete(perform: model.delete)
                    if model.canAddPlayers{
                        HStack {
                           
                            Button(action: {
                                add = true
                            }, label: {
                                Image(systemName: "plus.circle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.blue)
                            })
                            .buttonStyle(.plain)
                            .padding()
                            Spacer()
                        }
                    }
                }
                .listRowSeparator(.hidden)
                if model.players.count > 0{
                    Section {
                        HStack{
                            Spacer()
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                                newround = model.createRound(context: context)
                                
                            }, label: {
                                Text("Start Game")
                            })
                            .buttonStyle(.borderedProminent)
                            .padding()
                            Spacer()
                        }
                    }
                    .listRowSeparator(.hidden)
                }
                
                Section("Quick Add") {
                    LazyVGrid(columns: [ GridItem(.adaptive(minimum: 90))] ,spacing: 0){
                        ForEach(filteredRecentPlayers, id: \.self){ player in
                            Button(action: {
                                withAnimation {
                                    model.addPlayers([AddPlayerModel(player: player, tee: .white)])
                                }
                               
                            }, label: {
                                VStack
                                {
                                    PlayerImage(imageRadius: 60.0, player: player)
                                        .frame(width: 45)
                                    Text(player.firstName)
                                }
                            })
                            .buttonStyle(.plain)
                            .foregroundColor(.black)
                            .padding()
                           
                        }
                    }
                   
                }
                .listRowSeparator(.hidden)
                
            }
            .listStyle(.plain)
            .navigationDestination(isPresented: $add, destination: {
                PlayerChooserView( players: allPlayers , handler: model.addPlayers)
            })
            
        }
    }
    var filteredRecentPlayers : [Player]{
        return allPlayers.filter({!model.players.map({$0.player}).contains($0)})
    }
}
struct AddPlayerModel{
    var player : Player
    var tee : Tee
}
struct AddPlayerCell : View {
    @State var chooser : Bool = false
    @State var model : AddPlayerModel
    var body: some View {
        HStack {
            Text(model.player.name)
                .padding()
            Spacer()
           
               
                Button {
                    chooser = true
                } label: {
                    VStack{
                        Text("\(model.tee.name) Tees")
                            .padding([.leading, .trailing])
                            .padding([.top, .bottom], 3)
                        Text("Change")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
                

            
           
            
        }
        .sheet(isPresented:$chooser) {
            TeeSelectorView(name: model.player.firstName, tee: $model.tee)
                .presentationDetents([.medium])
        }
        
        
    }
}

#Preview {
    NewGameView(newround: Binding.constant(MainPreviewData.round))
        .modelContainer(MainPreviewData.previewContainer)
}
#Preview("Cell"){
    AddPlayerCell(model: AddPlayerModel( player:MainPreviewData.examplePlayer, tee: .blue))
}
