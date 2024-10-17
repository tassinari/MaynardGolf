//
//  SideHistogram.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/16/24.
//

import SwiftUI
import Charts

struct SideChartXYData : Identifiable, Hashable{
    var id: UUID = UUID()
    
    let x : String
    let y : Int
}
struct SideHistogramViewModel{
    let rawScores : [ScoreName : Int]
   
    func total(score: Int, in details: [Int]) -> Int {
        return details.filter{$0 == score}.count
    }
    
    var chartData : [SideChartXYData]{
        return rawScores.sorted(by: { a, b in
            a.key < b.key
        }).map{SideChartXYData(x: $0.shortName, y: $1)}
    }
    func label(forIndex: Int) -> String {
        return "par"
    }
    
}


struct SideHistogram: View {
    var model : SideHistogramViewModel
    var body: some View {
        let _ = Self._printChanges()
        Chart {
            ForEach(model.chartData, id: \.self) { d in
                BarMark(
                    x: .value("", d.y),
                    y: .value("", d.x)
                    ,height: .fixed(10)
                )
                
               // .foregroundStyle(.blue)
               // .cornerRadius(5)
            }
        }
        .chartXAxis{
            
        }
        
        .chartYAxis {
            AxisMarks { value in
              //  AxisGridLine(centered: true)
                AxisValueLabel( centered: true, anchor: .trailing){
                    Text(model.chartData[value.index].x)
                        .font(.caption2)
                }
            }
        }
        .frame(maxWidth: 220, maxHeight:90)
    }
    
    
}
#Preview {
    SideHistogram(model: SideHistogramViewModel(rawScores: [ .birdie : 12, .par : 32, .bogey : 71,.tripleBogey : 5, .doubleBogey : 32, .other : 8]))
        .frame(maxWidth: 300)
}
