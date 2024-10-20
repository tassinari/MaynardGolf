//
//  HoleView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/9/24.
//

import SwiftUI
import SwiftData


struct ScoreModel : Identifiable{
    var id : String { return player.name}
    let player : Player
    let score : Int?
    let hole : Int
    let overUnder : String

}
@Observable class HoleViewModel : Hashable, Identifiable{
    
    var id : String { return round.id + String(hole.number)}
    static func == (lhs: HoleViewModel, rhs: HoleViewModel) -> Bool {
        lhs.round.id == rhs.round.id && lhs.hole.number == rhs.hole.number
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(round.id)
        hasher.combine(hole.number)
    }
    init(round : Round, hole: Int = 1) throws{
        self.round = round
        guard let hl = try round.coursData.holes.first(where: {$0.number == hole}) else{
            throw DataError.holeNotFound
        }
        self.hole = hl
        self.players = []
        self.handler = handler
        refresh()
    }
    var entry : ScoreModel? = nil
    var hole : Hole
    private let round : Round
    var players : [ScoreModel]
    var handler :  ((Int) -> Void)?
    var cardViewModel : CardView.ViewModel?

    func refresh() {
        
        let pls = try? round.players.map({ pr in
            let i = pr.score.firstIndex { sc in
                sc.hole.number == hole.number
            }
        
            guard let i else {
                throw DataError.holeNotFound
            }
            return ScoreModel(player: pr.player, score: pr.score[i].score, hole: pr.score[i].hole.number, overUnder: pr.overUnderString)
        })
        if let pls{
            self.players = pls
        }
       
    }
    func update(player: Player, score: Int?) {
        
        //update round
        let pr = round.players.first { pr in
            pr.player == player
        }
        if let pr,  let index = pr.score.firstIndex(where: {$0.hole.number == hole.number}){
            pr.score[index] = Score(hole: hole, score: score)
        }
        
        self.players = players.map { sm in
            if sm.player == player{
                return ScoreModel(player: player, score: score, hole: sm.hole, overUnder: pr?.overUnderString ?? "-")
            }
            return sm
        }
        Task{ @MainActor in
            round.complete = round.scoresFilledIn
            try? MaynardGolfApp.sharedModelContainer.mainContext.save()
        }
    }
}

@Observable class HoleViewContainerModel{
    
    var verticalCardViewModel : VerticalCardViewModel? = nil
    var yardageFinder : Hole? = nil
    init(round: Round) throws {
        self.round = round
        var models : [HoleViewModel] = []
        for i in 1...9{
            let model = try HoleViewModel(round: round, hole: i)
            models.append(model)
        }
        holes = models
        selectedHole = round.nextHole
        if round.scoresFilledIn{
            selectedHole = 9
            completeViewModel = RoundCompleteViewModel(round: round)
        }
       
    }
    var selectedHole : Int
    var holes : [HoleViewModel] = []
    //var holeView : HoleViewType
    private let round : Round
    var completeViewModel : RoundCompleteViewModel? = nil
    
    func showCard(){
        verticalCardViewModel = VerticalCardViewModel(round: self.round)

    }
    func showYardage(){
        let model = holes[selectedHole - 1]
        yardageFinder = model.hole
    }
}

struct HoleViewContainer : View{
    @Environment(\.presentationMode) var presentationMode
    @Bindable var model : HoleViewContainerModel
    
    
    var body: some View{
        NavigationStack{
            TabView(selection: $model.selectedHole){
                ForEach(model.holes){ hole in
                    HoleView(model: hole)
                        .tag(hole.hole.number)
                        .onAppear(){
                            hole.refresh()
                        }
                }
            }
            
            .tabViewStyle(.page(indexDisplayMode: .never))
           .background(Color("bg").opacity(0.2))
           .sheet(item: $model.completeViewModel) { model in
               RoundCompleteView(viewModel: model)
                       .presentationDetents([.medium])

           }
           .sheet(item: $model.verticalCardViewModel) { model in
                   VerticalCardView(model:model)
                       .presentationDetents([.medium])

           }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack{
                        Button(action:{
                            model.showYardage()
                        },
                        label: {
                            Image(systemName: "flag")
                        }
                        )
                        .padding(.trailing)
                        Button("Card") {
                            model.showCard()
                        }
                    }
                    
                }
            }
        }
        .sheet(item: $model.yardageFinder) { hole in
            YardageFinderView(model: YardageFinderModel(hole: hole))
                .presentationDetents([.medium])
        }
    }
}

struct YardageView : View{
    @Bindable var model :  HoleViewModel
    var body: some View {
        VStack(spacing: 0){
            Group{
                Text(String(model.hole.yardage.blue))
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(.blue)
                
                Text(String(model.hole.yardage.white))
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    
                Text(String(model.hole.yardage.yellow))
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(.yellow)
                Text(String(model.hole.yardage.red))
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(.red)
            }
            .foregroundColor(.black)
        }
        .frame(maxWidth: 80)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}


struct HeaderView : View{
    @Bindable var model :  HoleViewModel
    var body: some View {
        VStack{
            HStack(alignment: .top){
                Image(model.hole.holeIconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                    .frame(maxHeight: 530, alignment: .top)
                    //.border(.red)
                    .padding([.leading], 30)
                    
                Spacer()
                VStack{
                    HoleNumberView(number: model.hole.number)
                    VStack(alignment: .center){
                        ParView(number: model.hole.par)
                            .padding()
                        YardageView(model: model)
                    }
                }
                .padding([.trailing], 30)
            }
        }
        .padding([.top], 20)
     
       
    }
}

struct ScoreArea : View{
    @Bindable var model :  HoleViewModel
    var body: some View {
        VStack{
           
            ForEach(model.players){ pl in
                HStack{
                    Text(pl.overUnder)
                        .font(.title2)
                    Text(pl.player.name)
                        .padding(.leading, 20)
                        .font(.title)
                    Spacer()
                    Button(action: {
                        model.entry = pl
                        
                    }, label: {
                        Group{
                            if let s = pl.score{
                                if s == 0{
                                    Text("-")
                                }else{
                                    Text(String(s))
                                }
                            }else{
                                Image(systemName: "plus.circle")
                            }
                        }
                        .font(.largeTitle)
                    })
                    
                }
                .padding(.trailing, 20)
                .padding(8)
            }
            
            
            
        }
        
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }
}

struct HoleView: View {
    @Bindable var model :  HoleViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0){
           
            VStack(alignment: .leading){
                HeaderView(model: model)
                
                ScoreArea(model: model)
                    .offset(CGSize(width: 0, height: 0))
            }
           
         
            Spacer()
        }
        .sheet(item: $model.entry) { score in
            EntryView(model: EntryView.ViewModel(name: score.player.firstName, hole: score.hole, entry: { sc in
                model.update(player: score.player, score: sc)
                model.entry = nil
            }))
            .background(.clear)
                .presentationDetents([.medium])
        }
        .sheet(item: $model.cardViewModel) { model in
            
                CardView(model:model)
                    .presentationDetents([.medium])
           
            
        }
    }
}

#Preview {
    if let r = MainPreviewData.round, let model = try? HoleViewContainerModel(round: r){
        return HoleViewContainer(model: model)
    }else{
        return Text("Error")
    }
}
