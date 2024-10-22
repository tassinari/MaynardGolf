//
//  CardPlayerScoreCell.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/21/24.
//

import SwiftUI
extension CardPlayerScoreCell{
    @Observable class ViewModel{
        internal init(player: Player, score: Int, toPar: String, round: Round) {
            self.player = player
            self.score = String(score)
            self.toPar = toPar
            if round.complete {
                Task { @MainActor in
                    self.trend = self.player.trend(for: score, round: round)
                }
            }
            
        }
        var player : Player
        var score : String
        var toPar : String
        var trend : Trend? = nil
        var color : Color {
            if let trend  {
                return trend == .down ? .green : .red
            }
            return .black
        }
    }
}


struct CardPlayerScoreCell: View {
    var model  : ViewModel
    var body: some View {
        HStack{
            PlayerImage(imageRadius: 60.0, player: model.player)
                .padding([.trailing], 5)
            
            Text(model.player.name)
            Spacer()
            Text(model.toPar)
            Color(.systemGray5).frame(width: 1, height: 25)
            Text(model.score)
                .padding([.trailing], 10)
            if let trend = model.trend {
                Group{
                    switch trend {
                    case .down:
                        Image(systemName: "arrowshape.down.fill")
                    case .up:
                        Image(systemName: "arrowshape.up.fill")
                    }
                }
                .foregroundColor(model.color)
                .padding([.trailing], 10)
                
            }
            
                
        }
        .padding([.top,.leading, .trailing], 5)
    }
}

#Preview {
    CardPlayerScoreCell(model: PlayerPreviewData.cardPlayerScoreCellModel)
}
