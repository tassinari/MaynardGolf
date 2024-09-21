//
//  CardPlayerScoreCell.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/21/24.
//

import SwiftUI
extension CardPlayerScoreCell{
    struct ViewModel{
        var name : String
        var score : String
        var image : Image
    }
}


struct CardPlayerScoreCell: View {
    @State var model  : ViewModel
    var body: some View {
        HStack{
            
            model.image
                .resizable()
                .frame(width: 60, height: 60)
                .aspectRatio(contentMode: .fit)
                .clipShape(Circle())
                .overlay(
                        Circle()
                            .stroke(Color("green3"), lineWidth: 4)
                    )
                .padding([.trailing], 5)
            
            Text(model.name)
            Spacer()
            Text(model.score)
        }
        .padding([.top,.leading, .trailing], 5)
    }
}

#Preview {
    CardPlayerScoreCell(model: PlayerPreviewData.cardPlayerScoreCellModel)
}
