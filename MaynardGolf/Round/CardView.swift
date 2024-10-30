//
//  CardView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/12/24.
//

import SwiftUI
import SwiftData

extension CardView{
    struct RowModel : Identifiable{
        var id : String{
            return UUID().uuidString //data.reduce("",+)
        }
        var color : Color
        var data : [String]
    }
    struct ViewModel : Identifiable{
        var id : Int { return 1}
        let rows : [RowModel]
    }
}

extension Round{
    
//    var verticalCard : VerticalCardView.ViewModel {
//        get throws{
//            
//        }
//    }
    
    var cardViewModel : CardView.ViewModel {
        get throws{
            guard let data = try? coursData.holes else {
                throw DataError.noCourseData
            }
            var result : [CardView.RowModel] = []
          //  let cols = 11
            //top row
            var hrow : [String] = ["Hole"]
            for i in 1...9{
                hrow.append(String(i))
            }
            hrow.append("Out")
           
            
            
            //yardages + par + handicap
            var prow : [String] = ["Par"]
            var brow : [String] = ["Blue"]
            var wrow : [String] = ["White"]
            var yrow : [String] = ["Yellow"]
            var rrow : [String] = ["Red"]
            var hcrow : [String] = ["HC"]
            for hole in data{
                prow.append(String(hole.par))
                brow.append(String(hole.yardage.blue))
                wrow.append(String(hole.yardage.white))
                yrow.append(String(hole.yardage.yellow))
                rrow.append(String(hole.yardage.red))
                hcrow.append(String(hole.handicap))
            }
            prow.append(String(data.map({$0.par}).reduce(0,+)))
            brow.append(String(data.map({$0.yardage.blue}).reduce(0,+)))
            wrow.append(String(data.map({$0.yardage.white}).reduce(0,+)))
            yrow.append(String(data.map({$0.yardage.yellow}).reduce(0,+)))
            rrow.append(String(data.map({$0.yardage.red}).reduce(0,+)))
            hcrow.append(String(""))
            
            //Scores
            var rows : [[String]] = []
            for pr in self.players{
                var row : [String] = []
                row.append(pr.player.firstName)
                for sc in pr.score{
                    row.append(sc.scoreString)
                }
                row.append(String(pr.score.compactMap({$0.score}).reduce(0,+)))
                rows.append(row)
            }
            
            
            //order
            result.append(CardView.RowModel(color: Color(.systemGray5), data: hrow))
            result.append(CardView.RowModel(color: .blue, data: brow))
            result.append(CardView.RowModel(color: .white, data: wrow))
            result.append(CardView.RowModel(color: Color(.systemGray5), data: prow))
            
            //scores
            for row in rows{
                result.append(CardView.RowModel(color: .white, data: row))
            }
            
            result.append(CardView.RowModel(color: .yellow, data: yrow))
            
            result.append(CardView.RowModel(color: .red, data: rrow))
            result.append(CardView.RowModel(color: Color(.systemGray5), data: hcrow))
            
            
            return CardView.ViewModel(rows: result)
        }
        
    }
    
}



struct CardView: View {
    @State var model : ViewModel
    var body: some View {
        
        Grid(alignment: .leading,horizontalSpacing: 0, verticalSpacing: 0) {
      
            ForEach(model.rows){ row in
                GridRow {
                    ForEach(row.data, id:\.self) { d in
                        Text(d)
                            .frame(maxWidth: .infinity)
                            .padding([.top, .bottom], 4)
                    }
                }
                .background(row.color)
                Divider()
                               .gridCellUnsizedAxes(.horizontal)
                
            }
        }
        //.background(Color(.systemGray6))
        .font(.caption2)
    }
    
    
    
}


    
struct VerticalCardViewModel : Identifiable{
    var id: PersistentIdentifier { round.persistentModelID }
    
    let round : Round
    init(round: Round) {
        self.round = round
        self.holes = round.players.first?.score.map({$0.hole}) ?? []
    }
    private let baseheaders : [String] = ["Hole", "Par"]
    var headers : [String] {
        return baseheaders + round.players.map { $0.player.firstName }
    }
    var footers : [String] {
        return ["Out"," "] + round.players.map({String($0.totalScore)})
    }
    let holes : [Hole]
}


struct VerticalCardView: View {
    
    @State var model : VerticalCardViewModel
    @State var showExit : Bool = false
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        
        VStack(spacing: 0) {
            if showExit{
                HStack {
                   
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle")
                            .padding()
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .background(.blue)
            }
            
            Grid(horizontalSpacing: 0,verticalSpacing: 0){
                GridRow {
                    ForEach(model.headers, id:\.self){ header in
                        Text(header)
                            .foregroundStyle(.white)
                            .font(.title3)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.blue)
                        
                    }
                    
                }
                
                ForEach(model.holes, id:\.self){ hole in
                    GridRow() {
                        Group{
                            Text(String(hole.number))
                            Text(String(hole.par))
                            ForEach(model.round.players, id:\.self){ player in
                                
                                Text(player.scoreString(hole: hole))
                                    .scoreMark(player.scoreInt(hole: hole), par: hole.par)
                                
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    }
                    .background(hole.number.isMultiple(of: 2) ? .blue.opacity(0.08) : Color(.white))
                }
                GridRow {
                    ForEach(model.footers, id:\.self){ footer in
                        Text(footer)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.blue.opacity(0.08) )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            }
        }
    }
    
    
    
}

#Preview("Traditional Card") {
    if let r = MainPreviewData.round, let data = try? r.cardViewModel{
        return CardView(model: data)
    }else{
        return Text("Error")
    }
   
   
    
   
}
#Preview("Vertical Card"){
    if let r = MainPreviewData.round{
        VerticalCardView(model: VerticalCardViewModel(round: r))
    }else{
        Text("Error")
    }
   
   
    
   
}
