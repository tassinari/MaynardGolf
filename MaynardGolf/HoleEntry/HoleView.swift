//
//  HoleView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/9/24.
//

import SwiftUI


struct ScoreModel : Identifiable{
    var id : String { return player.name}
    let player : Player
    let score : Int?
    let hole : Int
    let overUnder : String

}
@Observable class HoleViewModel{
    init(round : Round, hole: Int = 1) throws{
        
        self.round = round
        self.currentHole = try round.coursData.holes[hole - 1]
        let pls = try round.players.map({ pr in
            let i = pr.score.firstIndex { sc in
                sc.hole.number == hole
            }
            guard let i else {
                throw DataError.holeNotFound
            }
            return ScoreModel(player: pr.player, score: pr.score[i].score, hole: pr.score[i].hole.number, overUnder: pr.overUnderString)
        })
        self.players = pls
        self.handler = handler
        
    }
    var currentHole : Hole
    private let round : Round
    var players : [ScoreModel]
    var handler :  ((Int) -> Void)?
    var cardViewModel : CardView.ViewModel?
    var verticalCardViewModel : VerticalCardViewModel?
    
    func setCardModel(){
       // cardViewModel =  try? round.cardViewModel
        verticalCardViewModel = VerticalCardViewModel(round: round)
    }
    
    func update(player: Player, score: Int?) {
        
        //update round
        let pr = round.players.first { pr in
            pr.player == player
        }
        if let pr,  let index = pr.score.firstIndex(where: {$0.hole.number == currentHole.number}){
            pr.score[index] = Score(hole: currentHole, score: score)
        }
        
        self.players = players.map { sm in
            if sm.player == player{
                return ScoreModel(player: player, score: score, hole: sm.hole, overUnder: pr?.overUnderString ?? "-")
            }
            return sm
        }
    }
    func nextPressed(){
        if currentHole.number == 9{
            handler?(1)
        }else{
            handler?(currentHole.number + 1)
        }
       
    }
    func backPressed(){
        if currentHole.number == 1{
            handler?(9)
        }else{
            handler?(currentHole.number - 1)
        }
    }
    
   
}

@Observable class HoleViewContainerModel{
    
    enum HoleViewType {
        case model (HoleViewModel)
        case error  (DataError)
    }
    init(round: Round) {
        self.round = round
        if let model = try? HoleViewModel(round: round, hole: round.nextHole){
            self.holeView = HoleViewType.model(model)
            model.handler = holeChange
        }else{
            self.holeView = HoleViewType.error(DataError.holeNotFound)
        }
        
        
    }
    private func holeChange(_ i : Int){
        if let model = try? HoleViewModel(round: round, hole: i){
            self.holeView = HoleViewType.model(model)
            model.handler = holeChange
        }else{
            self.holeView = HoleViewType.error(DataError.holeNotFound)
        }
    }
    
    var holeView : HoleViewType
    private let round : Round
}

struct HoleViewContainer : View{
    @Environment(\.presentationMode) var presentationMode
    var model : HoleViewContainerModel
    var body: some View{
        NavigationStack{
            Group{
                switch model.holeView {
                case .model(let holeViewModel):
                    HoleView(model: holeViewModel)
                case .error(let dataError):
                    Text(String(describing: dataError))
                }
               
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Card") {
                        
                        switch model.holeView {
                        case .model(let holeViewModel):
                            holeViewModel.setCardModel()
                        case .error( _):
                            //no op
                            break
                        }
                        
                    }
                }
            }
        }
        
        
        
    }
}

struct HoleView: View {
    @Bindable var model :  HoleViewModel
    @State var entry : ScoreModel? = nil
    var body: some View {
        VStack{
            //let _ = Self._printChanges()
            HStack(alignment: .top){
                Image("hole1")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .padding([.bottom], 40)
                VStack{
                    HoleNumberView(number: model.currentHole.number)
                    ParView(number: model.currentHole.par)
                        .padding()
                    
                }
                
                .padding([.leading, .trailing])
                
               
            }
            
            VStack{
                HStack(spacing: 0){
                    Group{
                        Text(String(model.currentHole.yardage.blue))
                            .padding(5)
                            .frame(maxWidth: .infinity)
                            .background(.blue)
                        
                        Text(String(model.currentHole.yardage.white))
                            .padding(5)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            
                        Text(String(model.currentHole.yardage.yellow))
                            .padding(5)
                            .frame(maxWidth: .infinity)
                            .background(.yellow)
                        Text(String(model.currentHole.yardage.red))
                            .padding(5)
                            .frame(maxWidth: .infinity)
                            .background(.red)
                    }
                    .foregroundColor(.black)
                }
                //.frame(width: 80)
                //.clipShape(RoundedRectangle(cornerRadius: 10))
                ForEach(model.players){ pl in
                    HStack{
                        Text(pl.overUnder)
                        Text(pl.player.name)
                            .padding(.leading, 20)
                            .font(.largeTitle)
                        Spacer()
                        Button(action: {
                            entry = pl
                            
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
                    .padding()
                }
                
                
                
            }
            Spacer()
           // .background(.white)
            HStack{
                Button(action: {
                    model.backPressed()
                }, label: {
                    HStack{
                    
                        Image(systemName: "arrowshape.left")
                        
                    }
                    .font(.title)
                        
                })
                .padding()
                Spacer()
                Button(action: {
                    model.nextPressed()
                }, label: {
                    HStack{
                           
                        Image(systemName: "arrowshape.right")
                        
                    }
                    .font(.title)
                        
                })
                .padding()
            }
           
        }
    
        .sheet(item: $entry) { score in
            EntryView(model: EntryView.ViewModel(name: score.player.firstName, hole: score.hole, entry: { sc in
                model.update(player: score.player, score: sc)
                entry = nil
            }))
                .presentationDetents([.medium])
        }
        .sheet(item: $model.cardViewModel) { model in
            
                CardView(model:model)
                    .presentationDetents([.medium])
           
            
        }
        .sheet(item: $model.verticalCardViewModel) { model in
            
                VerticalCardView(model:model)
                    .presentationDetents([.medium])
           
            
        }
        
        
        
        
    }
}

#Preview {
    if let r = MainPreviewData.round{
        return HoleViewContainer(model: HoleViewContainerModel(round: r))
    }else{
        return Text("Error")
    }
}
