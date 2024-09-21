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
    var model : ViewModel = ViewModel()
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
                            
                            .padding()
                            Spacer()
                        }
                    }
                }
                Section("Recent") {
                    ForEach(filteredRecentPlayers){ player in
                        Button(action: {
                            withAnimation {
                                model.addPlayers([player])
                            }
                           
                        }, label: {
                            HStack{
                                Text(player.name)
                                Spacer()
                            }
                        })
                        .foregroundColor(.black)
                    }
                   
                }
                
            }
            .navigationDestination(isPresented: $add, destination: {
                PlayerChooserView( handler: model.addPlayers)
            })
            .navigationTitle("New Game")
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
    NewGameView(newround: Binding.constant(nil))
}
