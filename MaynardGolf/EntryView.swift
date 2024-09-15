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
        let entry : (Int)->Void
    }
    
}

struct EntryView: View {
    @State var model : ViewModel
    var body: some View {
        
        let columns = [
                GridItem(.adaptive(minimum: 80))
            ]
        VStack(alignment: .center) {
            Text("Enter \(model.name)'s Score")
                .foregroundStyle(Color("green5"))
                .font(.largeTitle)
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
                }
                
            }
            .padding([.leading, .trailing], 40)
            Spacer()
        }
        
    }
}

#Preview {
    EntryView(model: EntryView.ViewModel(name: "Mark", entry: {_ in}))
}
