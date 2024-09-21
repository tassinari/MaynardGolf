//
//  PlayerDetailView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/21/24.
//

import SwiftUI

struct PlayerDetailView: View {
    @State var player: Player
    var body: some View {
        VStack{
            VStack{
                Image("phil")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(Circle())
                    .overlay(
                            Circle()
                                .stroke(Color("green3"), lineWidth: 4)
                        )
                    .padding([.trailing], 5)
                Text(player.name)
                    .font(.largeTitle)
                    .padding()
            }
            .padding()
            Spacer()
        }
        .toolbar {
            Button {
                
            } label: {
                Text("Edit")
            }

        }
        
    }
}

#Preview {
    NavigationStack {
        PlayerDetailView(player: PlayerPreviewData.examplePlayer)
    }
    
}
