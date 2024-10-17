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
            
            PlayerImage(imageRadius: 60.0, player: player)
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
               
                Text(round.formattedDate)
                    .font(.callout)
                    .fontWeight(.thin)
                Spacer()
                Text(round.formattedTime)
                    .font(.callout)
                    .fontWeight(.thin)
                
            }
            .padding([.leading, .trailing])
            
            HStack{
                ForEach(round.sortedPlayers){ playerR in
                    
                    HStack{
                        VStack {
                            Text(playerR.player.firstName)
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(playerR.player.color.color)
                            Text(playerR.overUnderString)
                                .font(.callout)
                                .fontWeight(.regular)
                                
                               
                        }
                        .padding([.trailing])
                        Color(.systemGray4).frame(width: 1,height: 30)
                    }
                    .padding([.leading])
                   
                }
                Spacer()
                Image(systemName: "cloud.sun")
                    .font(.largeTitle)
                    .fontWeight(.thin)
                    .padding( 12)
                
            }
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
