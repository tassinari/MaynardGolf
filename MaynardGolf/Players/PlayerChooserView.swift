//
//  PlayerChooserView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/13/24.
//

import SwiftUI
import SwiftData


struct PlayerChooserView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var add : Bool = false
    var players : [Player]
    @State var chosenPlayers : Set<Player> = []
    let handler : ([AddPlayerModel]) -> Void
    var body: some View {
        VStack{
            if players.isEmpty{
                ContentUnavailableView {
                    Label("No Players Yet", systemImage: "person.circle")
                } description: {
                  
                    Button(action: {
                        add = true
                    }, label: {
                        Text("Add One")
                    })
                    .padding()
                }
                VStack{
                   
                }
               
            }
            else{
                List(){
                    
                    ForEach(players){player in
                        Button(action: {
                            if chosenPlayers.contains(player){
                                chosenPlayers.remove(player)
                            }else{
                                chosenPlayers.insert(player)
                            }
                        }, label: {
                            HStack{
                                Text(player.name)
                                Spacer()
                                if chosenPlayers.contains(player){
                                    Image(systemName: "checkmark")
                                }
                                
                            }
                        })
                        .foregroundColor(.black)
                        
                        
                    }
                    
                    HStack{
                        Spacer()
                        Button(action: {
                            add = true
                        }, label: {
                            Text("Add New Player")
                        })
                        Spacer()
                    }
                    
                }
            }
        }
       
        .toolbar(content: {
            Button(action: {
                handler(Array(chosenPlayers).map({AddPlayerModel(player: $0, tee: .white)}))
                presentationMode.wrappedValue.dismiss()
            }, label: {
                Text("Done")
            })
        })
        .fullScreenCover(isPresented: $add, content: {
            PlayerEntryView()
                
        })
    }
}

#Preview {
    NavigationStack{
        PlayerChooserView(players: PlayerPreviewData.somePlayers, handler: {_ in })
            .modelContainer(PlayerPreviewData.previewContainer)
    }
    
}
