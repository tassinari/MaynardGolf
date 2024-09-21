//
//  PlayerTileView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/18/24.
//

import SwiftUI
import SwiftData

struct PlayerTileView: View {
    let player  : Player
    var body: some View {
        VStack{
            HStack(alignment: .top) {
                Image("phil")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(Circle())
                    .overlay(
                            Circle()
                                .stroke(Color("green3"), lineWidth: 4)
                        )
                    .padding([.trailing], 5)
                    
                VStack(alignment: .leading) {
                    HStack{
                        Text(player.name)
                            .font(.title2)
                        Spacer()
                        Text("2")
                            .foregroundStyle(.white)
                            .frame(width: 45, height: 45)
                            .background(
                               Circle()
                                .foregroundColor(Color("green2"))
                                 .padding(4)
                             )
                    }
                    Gauge(value: 77, in: 64...81) {}
                currentValueLabel: {
                                   Text(Int(72), format: .number)
                               } minimumValueLabel: {
                                   Text("63")
                                       .font(.caption)
                                       
                               } maximumValueLabel: {
                                   Text("81")
                                       .font(.caption)
                               }
                               .padding([.trailing], 60)
                               .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
                               .gaugeStyle(.accessoryLinear)
                               

                    
                              
                }
               
               
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        
        .padding()
        .background(
            Color("green1").opacity(0.2)
                
        )
        .cornerRadius(20)
        .shadow(color: .gray.opacity(0.4), radius: 2, x: 0, y: 0)
        
        .padding([.leading, .trailing], 10)
        
    }
}

#Preview {
    if let p = try? ModelContext(PlayerPreviewData.previewContainer).fetch(FetchDescriptor<Player>()).first {
        return PlayerTileView(player: p).border(Color.red, width: 1)
    }else{
        return Text("No Preview")
    }
}
