//
//  RoundCellView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/22/24.
//

import SwiftUI

struct PlayerCircle : View{
    @State var overUnder : AttributedString
    @State var player: Player
    
    var body : some View{
        ZStack{
            
            PlayerImage(player: player)
            Text(overUnder)
                .foregroundStyle(.white)
                .font(.callout)
                .fontWeight(.medium)
                .padding(5)
                //.frame(minWidth: 80 )
                .background(
                    Circle()
                    .fill(player.color.color)
                 )
                .offset(CGSize(width: 22, height: 25))
                
                
           
            
        }
    }
    
}


struct RoundCellView: View {
    @State var round: Round 
    var body: some View {
        VStack(alignment: .leading){
            
            HStack{
                Image(systemName: "cloud.sun")
                    .font(.callout)
                    .padding([.bottom], 5)
                Text(round.formattedDateWithTime)
                Spacer()
                
            }
            .padding()
            
            HStack{
                ForEach(round.sortedPlayers){ playerR in
                    PlayerCircle(overUnder: playerR.overUnderAttributted, player: playerR.player)
                        .padding([.leading],10)
//                            Text(player.overUnderString)
//                                .foregroundStyle(.blue)
//                                .frame(minWidth: 35)
//                            Text(player.player.name)
                }
                
            }
            
//            VStack(alignment: .leading,spacing: 5){
//                Grid(alignment: .leading){
//                    ForEach(round.sortedPlayers){ player in
//                        GridRow {
//                            Text(player.overUnderString)
//                                .foregroundStyle(.blue)
//                                .frame(minWidth: 35)
//                            Text(player.player.name)
//                           
//                        }
//                       
//                    }
//                }
//                
//           }
            
        }
    }
   
}

#Preview {
    if let r = MainPreviewData.round{
        RoundCellView(round: r)
    }else{
        Text("No Preview Data")
    }
   
}
