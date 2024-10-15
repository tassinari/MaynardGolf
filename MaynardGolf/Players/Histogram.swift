//
//  Histogram.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/9/24.
//

import SwiftUI
import Charts

struct ChartXYData : Identifiable, Hashable{
    var id: UUID = UUID()
    
    let x : Int
    let y : Int
}
struct HistogramViewModel{
    let rawScores : [Int]
    let par : Int
    
    func total(score: Int, in details: [Int]) -> Int {
        return details.filter{$0 == score}.count
    }
    
    var scale : ClosedRange<Int>{
        return 1...9
    }
    var chartData : [ChartXYData]{
        var values : [ChartXYData] = []
        for i in 2..<9{
            values.append(ChartXYData(x: i, y: total(score: i, in: rawScores)))
        }
        return values
    }
    func label(for index : Int) -> String {
        switch index + 1 {
        case 2: return "2"
        case 3: return "3"
        case 4: return "4"
        case 5: return "5"
        case 6: return "6"
        case 7: return "7"
        case 8: return "8+"
        default:
            return ""
        }
    }
}


struct Histogram: View {
    @State var model : HistogramViewModel
    var body: some View {
        Chart {
            ForEach(model.chartData, id: \.self) { d in
                BarMark(
                    x: .value("", d.x),
                    y: .value("", d.y)
                    ,width: .fixed(5)
                )
                .foregroundStyle(.blue)
                .cornerRadius(5)
            }
        }
        
        .chartYAxis{
            AxisMarks(
                   values: [0]
               ) {
                   AxisGridLine()
               }
        }
        .chartXAxis{
            
            AxisMarks(values: .stride(by: 1)) { value in
                if value.index + 1 == model.par {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 12.5))
                        .foregroundStyle(.green.opacity(0.2))
                    AxisTick(stroke: StrokeStyle(lineWidth: 12.5))
                        .foregroundStyle(.green.opacity(0.2))
                }
                if value.index == 7 {
                    AxisValueLabel(model.label(for: value.index), anchor: .top)
                        .offset(CGSize(width: 3, height: 0))
                        .font(.callout)
                }else{
                    AxisValueLabel(model.label(for: value.index), anchor: .top)
                        .font(.callout)
                }
               
            }
        }
        .chartXScale(
            domain: (model.scale)
        )
        .frame(width: 150, height: 60)
        .padding()
    }
    
    
}
#Preview {
    Histogram(model: HistogramViewModel(rawScores: [7,5,4,3,3,3,5,7,8,4,4,6,8,9], par: 5))
}
