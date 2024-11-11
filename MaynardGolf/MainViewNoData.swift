//
//  MainViewNoData.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 11/10/24.
//

import SwiftUI

struct MainViewNoData: View {
    @Binding var newGame: Bool
    var body: some View {
        ContentUnavailableView {
            Label("Welcome", systemImage: "figure.golf.circle")
        } description: {
            VStack{
                Text("Data will appear here as you play.")
                Button("Start a Round") {
                    newGame = true
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            
        }
       
    }
}

#Preview {
    MainViewNoData(newGame: Binding<Bool>.constant(false))
}
