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
        var players : [Player] = []
        var ninehole : Bool  = true
        var canAddPlayers : Bool{
            return players.count < maxPlayers
        }
        func addPlayers(_ pl : [Player]){
            for p in pl{
                if canAddPlayers && !players.contains(p){
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
            for p in players{
                
                let pr = PersonRound(player: p, score: holes.map{Score(hole:$0, score: nil)})
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
                Section("Holes") {
                    HStack{
                        Button(action: {
                            model.ninehole.toggle()
                        }, label: {
                            Text("Nine")
                        })
                        .disabled(model.ninehole)
                        Button(action: {
                            model.ninehole.toggle()
                        }, label: {
                            Text("Eighteen")
                        })
                        .disabled(!model.ninehole)
                    }
                }
                Section("Players") {
                    ForEach(model.players){ player in
                        Text(player.name)
                    }
                    .onDelete(perform: model.delete)
                    if model.canAddPlayers{
                        Button(action: {
                            add = true
                        }, label: {
                            Text("Add")
                        })
                        .buttonStyle(.bordered)
                    }
                }
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
                }
                Section("Quick Add") {
                    LazyVGrid(columns: [ GridItem(.adaptive(minimum: 90))] ,spacing: 0){
                        ForEach(filteredRecentPlayers, id: \.self){ player in
                            Button(action: {
                                withAnimation {
                                    model.addPlayers([player])
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
                
            }
            .listStyle(.plain)
            .navigationDestination(isPresented: $add, destination: {
                PlayerChooserView( players: allPlayers , handler: model.addPlayers)
            })
            .navigationTitle("New Round")
//            .toolbar {
//                Button(action: {
//                    
//                }, label: {
//                    Text("Create Player")
//                })
//            }
            
        }
    }
    var filteredRecentPlayers : [Player]{
        return allPlayers.filter({!model.players.contains($0)})
    }
}

#Preview {
    NewGameView(newround: Binding.constant(MainPreviewData.round))
        .modelContainer(MainPreviewData.previewContainer)
}
