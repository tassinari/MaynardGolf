//
//  RoundCellView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/22/24.
//

import SwiftUI

struct RoundCellView: View {
    @State var round: Round 
    var body: some View {
        HStack {
            VStack(alignment: .leading,spacing: 5){
                Grid(alignment: .leading){
                    ForEach(round.sortedPlayers){ player in
                        GridRow {
                            Text(player.overUnderString)
                                .foregroundStyle(.blue)
                                .frame(minWidth: 35)
                            Text(player.player.name)
                           
                        }
                       
                    }
                }
                
            }
            
            Spacer()
            VStack{
                Image(systemName: "cloud.sun")
                    .padding([.bottom], 5)
                Text(round.formattedDate)
                    
                    
            }
            .font(.headline)
            .foregroundColor(.primary)
            .padding()
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
