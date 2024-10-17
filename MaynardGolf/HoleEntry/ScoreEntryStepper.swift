//
//  ScoreEntryStepper.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/17/24.
//

import SwiftUI

struct ScoreEntryStepper: View {
    
    let maxScore: Int = 25
    let minScore: Int = 1
    @State var score: Int = 7
    @Binding var stepper : Bool
    @State var model : EntryView.ViewModel
    var body: some View {
        VStack {
            Text("Enter \(model.name)'s score on hole \(model.hole)")
                .foregroundStyle(Color("green5"))
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            VStack {
                Spacer()
                Text(String(score))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("green5"))
                    .padding()
                
                HStack{
                    Button {
                        if score > minScore {
                            score -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color("green5"))
                            .padding()
                        
                    }
                    
                    Button {
                        if score < maxScore {
                            score += 1
                        }
                        
                    } label: {
                        Image(systemName: "plus")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color("green5"))
                            .padding()
                        
                    }
                    
                    
                    
                }
                Spacer()
            }
            Spacer()
            HStack{
                Button {
                    withAnimation {
                        stepper.toggle()
                    }
                    
                } label: {
                   Text("Cancel")
                        .font(.largeTitle)
                        .fontWeight(.regular)
                        .foregroundStyle(Color("green5"))
                        .padding()
                  
                }
                Spacer()
                Button {
                    model.entry(score)
                    
                } label: {
                   Text("Done")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color("green5"))
                        .padding()
                  
                }
            }

        }
    }
}

#Preview {
    Color.white
        .sheet(isPresented: Binding<Bool>.constant(true)) {
            ScoreEntryStepper(stepper: Binding<Bool>.constant(false), model: EntryView.ViewModel(name: "Mark", hole: 13, entry: {_ in}))
                .presentationDetents([.medium])
        }
        
}
