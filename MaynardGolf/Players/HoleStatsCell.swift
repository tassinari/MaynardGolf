//
//  HoleStatsCell.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/9/24.
//

import SwiftUI

enum ScoreName{
    case doubleEagle, eagle, birdie, par, bogey, doubleBogey, tripleBogey, other
    
    var description : String{
        switch self{
        case .doubleEagle: return "Double Eagle"
        case .eagle: return "Eagle"
        case .birdie: return "Birdie"
        case .par: return "Par"
        case .bogey: return "Bogey"
        case .doubleBogey: return "Double Bogey"
        case .tripleBogey: return "Triple Bogey"
        case .other: return "Other"
        }
    }
}

struct HoleStatsModel : Identifiable{
    
    var id : Int { return holeNumber}
    let scores : [Int]
    let holeNumber : Int
    let par : Int
    let average : Double
    let scoreString : ScoreName
    
}

struct HoleStatsCell: View {
    @State var holeStats : HoleStatsModel
    var average : some View {
        VStack(alignment: .center, spacing: 0){
            
            Text(String(String(format: "%.1f", holeStats.average)))
                .foregroundStyle(.white)
                .frame(width: 55, height: 55)
                .background(
                    Circle()
                        .foregroundColor(Color("green2"))
                        .padding(4)
                )
            Text(holeStats.scoreString.description)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(Color("green2"))
            
        }
    }
    var holeNumber : some View {
        ZStack{
            Group{
                Text(String(holeStats.holeNumber))
                    . font(.title)
                Text("HOLE")
                    .font(.caption2)
                    .offset(CGSize(width: 0, height: 16))
            }
            .offset(CGSize(width: 0, height: -6))
            
            .foregroundStyle(Color("green4"))
            .fontWeight(.bold)
            
        }
       
            .frame(width: 60, height: 60)
            .background(
               Circle()
                 .stroke(Color("green4"), lineWidth: 6)
                 .padding(4)
             )
        
    }
    var body: some View {
        VStack{
            HStack{
                VStack(alignment: .center) {
                    holeNumber
                    Text("Par \(String(holeStats.par))")
                        .font(.callout)
                        .foregroundStyle(.gray)
                    
                }
                .padding()
                Spacer()
                HStack(alignment: .center) {
                    Histogram(data: holeStats.scores)
                    
                }
                Spacer()
                average
                    .padding()

            }
            Spacer()
        }
    }
}

#Preview {
    HoleStatsCell(holeStats : HoleStatsModel(scores: [3,3,3,4,4,4,4,4,5,5,5,5,5,5,6,6,7,7,7,4,4,4,], holeNumber: 8, par: 4, average: 4.9, scoreString: .par))
}
