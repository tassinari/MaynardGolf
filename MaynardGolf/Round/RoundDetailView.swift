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
        if round.inProgress{
            roundInProgress = round
        }
    }
    
    var round : Round
    
    var courseName : String{
        return courseData.name
    }
    private let courseData : Course
    let cardViewModel : CardView.ViewModel
    var roundInProgress : Round? = nil
}

struct RoundDetailView: View {
    @State var model : RoundDetailModel
    
    var body: some View {
        VStack(spacing: 0){
            List(){
                Section(){
                    HStack{
                        Group{
                            VStack(alignment: .leading){
                                Text(model.courseName)
                                    .font(.title2)
                                Text(model.round.formattedDateWithTime)
                                    .font(.callout)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            WeatherView()
                        }

                    }
                    .padding([.bottom], 5)
                }
                Section(header:
                    HStack{
                    Text("Score Card")
                    Spacer()
                    Button {
                        
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                    }

                    
                    }
                    .padding()
                            
                ){
                    VerticalCardView(model: VerticalCardViewModel(round: model.round))
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
               
                Section(header: Text("Players")){
                    ForEach(model.round.sortedPlayers){ p in
                        CardPlayerScoreCell(model: CardPlayerScoreCell.ViewModel(player: p.player, score: String(p.overUnderString)))
                }
                }
            }
            .listStyle(.plain)
            
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    model.roundInProgress = model.round
                }
            }
        }
        .fullScreenCover(item: $model.roundInProgress) { round in
            if let model = try? HoleViewContainerModel(round: round){
                HoleViewContainer(model: model)
            }else{
                Text("Error")
            }
            
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
