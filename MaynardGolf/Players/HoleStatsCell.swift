//
//  HoleStatsCell.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/9/24.
//

import SwiftUI



struct HoleStatsModel : Identifiable{
    
    var id : Int { return holeNumber}
    var icon : String
    let scores : [Int]
    let holeNumber : Int
    let par : Int
    let average : Double
    let scoreString : ScoreName
    
    ///Clamps the top score to 8, so the histogram will max and show 8+
    var displayScores : [Int]{
        return scores.map{ score in
            if score > 8 { return 8}
            return score
        }
    }
    
    var scoreName : String{
        Player.scoreName(avg: average, fromPar: par).name
    }
    
}

struct HoleStatsCell: View {
    @State var holeStats : HoleStatsModel
    var average : some View {
        VStack(alignment: .center, spacing: 0){
            StatView(stat: String(String(format: "%.1f", holeStats.average)), title: "Avg.")
            
        }
    }
    var holeNumber : some View {
        HStack {
            
            VStack(spacing: 0){
                
                Text(attributedHole(hole: holeStats.holeNumber))
                    //.foregroundStyle(.gray)
                    .frame(width: 80, height: 80)
                    .offset(CGSize(width: 5, height: 0))
                    .background(
                        Circle()
                            .foregroundColor(Color(.systemGray6))
                            
                            .padding(4)
                    )
                Text("Par \(String(holeStats.par))")
                    .font(.callout)
                    .foregroundStyle(.gray)
            }
           
          
           
        }
       
    }
    var body: some View {
        HStack(spacing: 0){
            Image(holeStats.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 46)
                .padding([.leading],5)
            VStack(alignment: .center, spacing: 4){
                HStack(alignment: .center) {
                    Text(attributedHole(hole: holeStats.holeNumber))
                        .font(.title2)
                        .fontWeight(.regular)
                   
                    Text("Par \(String(holeStats.par))")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(holeStats.scoreName)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    
                }
                .padding([.leading, .trailing])
                HStack(alignment: .center) {
                    VStack(){
                       
                        Text("Average")
                            .font(.caption)
                            .fontWeight(.thin)
                            .foregroundStyle(.gray)
                        Text(String(format: "%.1f", holeStats.average))
                            .font(.title2)
                            .fontWeight(.bold)
                       
                    }
                    .padding([.leading, .trailing])
                    Spacer()
                    Histogram(model: HistogramViewModel( rawScores: holeStats.displayScores, par: holeStats.par))
                        .padding([.trailing])
                       
                    
                }

            }
            
        }
    }
    func attributedHole(hole : Int) -> AttributedString{
        var suffix = "th"
        switch hole{
        case 1:
            suffix = "st"
        case 2:
            suffix = "nd"
        case 3:
            suffix = "rd"
        default:
            break
            
        }
        var superscript =  AttributedString(suffix)
        superscript.font = .caption
        superscript.baselineOffset = 12.0
        var str = AttributedString(String(hole))
        str.font = .title
        return str + superscript
        
    }
}

#Preview {
    HoleStatsCell(holeStats : HoleStatsModel(icon: "hole4", scores: [3,3,3,4,4,4,4,4,5,5,5,5,5,5,6,6,7,7,7,4,4,4,], holeNumber: 8, par: 4, average: 4.9, scoreString: .par))
}
