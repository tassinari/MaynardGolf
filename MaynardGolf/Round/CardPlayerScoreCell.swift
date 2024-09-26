//
//  CardPlayerScoreCell.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/21/24.
//

import SwiftUI
extension CardPlayerScoreCell{
    struct ViewModel{
        var player : Player
        var score : String
    }
}


struct CardPlayerScoreCell: View {
    @State var model  : ViewModel
    var body: some View {
        HStack{
            PlayerImage(player: model.player)
                .padding([.trailing], 5)
            
            Text(model.player.name)
            Spacer()
            Text(model.score)
        }
        .padding([.top,.leading, .trailing], 5)
    }
}

#Preview {
    CardPlayerScoreCell(model: PlayerPreviewData.cardPlayerScoreCellModel)
}
