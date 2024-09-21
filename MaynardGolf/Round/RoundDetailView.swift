//
//  SwiftUIView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/15/24.
//

import SwiftUI


struct RoundDetailModel{
    
    init(round: Round) throws {
        self.round = round
        self.courseData = try round.coursData
        cardViewModel = try round.cardViewModel
    }
    
    var round : Round
    var sortedByScore : [PersonRound]{
        return round.players.sorted { p1, p2 in
            return p1.score.compactMap({$0.score}).reduce(0,+) < p2.score.compactMap({$0.score}).reduce(0,+)
        }
    }
    var courseName : String{
        return courseData.name
    }
    private let courseData : Course
    let cardViewModel : CardView.ViewModel
}

struct RoundDetailView: View {
    @State var model : RoundDetailModel
    @State var roundInProgress : Round? = nil
    var body: some View {
        VStack(spacing: 0){
            HStack{
                Group{
                    Text(model.courseName)
                        .padding([.top, .leading,.trailing])
                    Spacer()
                    Text(model.round.formattedDate)
                        .padding([.top, .leading,.trailing])
                }
                .font(.callout)
                
                
                
                
                
            }
            .padding([.bottom], 5)
            .background(Color(.green1))
            
            CardView(model: model.cardViewModel)
            Spacer()
            List(){
                ForEach(model.sortedByScore){ p in
                    CardPlayerScoreCell(model: CardPlayerScoreCell.ViewModel(name: p.player.name, score: String(p.score.compactMap({$0.score}).reduce(0,+)), image: Image("phil")))
//                    HStack{
//                        Text(p.player.name)
//                        Spacer()
//                        Text(String(p.score.compactMap({$0.score}).reduce(0,+)))
//                    }
                }
            }
            
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    roundInProgress = model.round
                }
            }
        }
        .fullScreenCover(item: $roundInProgress) { round in
            HoleViewContainer(model: HoleViewContainerModel(round: round))
        }
        
    }
    
}

#Preview {
    if let r = MainPreviewData.round, let model = try? RoundDetailModel(round: r){
        return RoundDetailView(model: model)
    }else{
        return Text("Error")
    }
    
}
