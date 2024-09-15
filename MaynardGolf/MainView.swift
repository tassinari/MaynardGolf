//
//  MainView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/12/24.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Query var rounds : [Round]
    @State private var path = [Int]()
    @State var newGame : Bool = false
    @State var roundInProgress : Round? = nil
    
    var body: some View {
        NavigationStack(path: $path){
            
            VStack{
                ForEach(rounds){ round in
                    NavigationLink(value: round, label: {
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
            .navigationTitle("Maynard Golf")
            .toolbar {
                Button("New Game") {
                    newGame = true
                }
            }
            .navigationDestination(isPresented: $newGame, destination: {
                NewGameView(newround: $roundInProgress)
            })
            .navigationDestination(for: Round.self) { selection in
                if let d = try? selection.cardViewModel{
                    CardView(model: d)
                }else{
                    Text("Error")
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
