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
    @State var otherShowing : Bool = false
    @State var score : String = ""
    
    var body: some View {
        
        let columns = [
                GridItem(.adaptive(minimum: 80))
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
                              .padding(30)
                              .background(Color("green4"))
                              .clipShape(Circle())
                        })
                        
                            
                    }
                    Button(action: {
                        model.entry(nil)
                    }, label: {
                        Image(systemName: "delete.left")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                          .padding(30)
                          .background(Color("green4"))
                          .clipShape(Circle())
                    })
                    Button(action: {
                        model.entry(0)
                    }, label: {
                        Text("-")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                          .padding(30)
                          .background(Color("green4"))
                          .clipShape(Circle())
                    })
                    Button(action: {
                        otherShowing = true
                    }, label: {
                        Image(systemName: "rectangle.and.pencil.and.ellipsis")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                          .padding(30)
                          .background(Color("green4"))
                          .clipShape(Circle())
                    })
                    
                    
                }
                
            }
            .padding([.leading, .trailing], 40)
            Spacer()
            
        }
        .alert("Score", isPresented: $otherShowing) {
            TextField("par", text: $score)
                .keyboardType(.numberPad)
            Button("OK", action: {
                if let score = Int(score) {
                    model.entry(score)
                }
            })
                } message: {
                    Text("Enter Mark's score on hole 4")
                }
        
    }
}

#Preview {
    EntryView(model: EntryView.ViewModel(name: "Mark", hole: 13, entry: {_ in}))
}
