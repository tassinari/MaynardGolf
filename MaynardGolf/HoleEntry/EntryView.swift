//
//  EntryView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/10/24.
//

import SwiftUI

extension EntryView{
    
    struct ViewModel  {
        let scores = [2,3,4,5,6,7]
        let name : String
        let hole : Int
        let entry : (Int?)->Void
    }
    
}
struct EntryView: View {
    @State var model : ViewModel
    @State var stepper : Bool = false
    
    var body: some View {
        if stepper{
            ScoreEntryStepper(stepper: $stepper, model: model)
                .transition(.slide)
                .background(.ultraThinMaterial)
        }else{
            EntryViewButtons(model: model, stepper: $stepper)
                .background(.ultraThinMaterial)
        }
        
        
    }
}

struct EntryViewButtons: View {
    @State var model : EntryView.ViewModel
    @State var score : String = ""
    @Binding var stepper : Bool
    var body: some View {
        
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]
        VStack(alignment: .center) {
            Text("Enter \(model.name)'s score on hole \(model.hole)")
                .foregroundStyle(Color("green5"))
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            HStack{
                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(model.scores, id: \.self){score in
                        Button(action: {
                            model.entry(score)
                        }, label: {
                            Text(String(score))
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                                .fontWeight(.bold)
                              .frame(width: 80, height: 80)
                              .background(Color("green4"))
                              .clipShape(Circle())
                            
                        })
                        .buttonStyle(.plain)
                        
                            
                    }
                    Button(action: {
                        model.entry(nil)
                    }, label: {
                        Image(systemName: "delete.left")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                          .frame(width: 80, height: 80)
                          .background(Color("green4"))
                          .clipShape(Circle())
                    })
                    Button(action: {
                        model.entry(0)
                    }, label: {
                        Text(String("-"))
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                          .frame(width: 80, height: 80)
                          .background(Color("green4"))
                          .clipShape(Circle())
                    })
                    Button(action: {
                        withAnimation {
                            stepper = true
                        }
                        
                    }, label: {
                        Image(systemName: "plus")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                          .frame(width: 80, height: 80)
                          .background(Color("green4"))
                          .clipShape(Circle())
                    })
                    
                    
                }
                
            }
            .padding([.leading, .trailing], 40)
            Spacer()
            
        }
        
    }
}

#Preview {
    Color.white.sheet(isPresented: Binding<Bool>.constant(true)){
        EntryView(model: EntryView.ViewModel(name: "Mark", hole: 13, entry: {_ in}))
            .presentationDetents([.medium])
    }
}
