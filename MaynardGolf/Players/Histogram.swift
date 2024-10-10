//
//  Histogram.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/9/24.
//

import SwiftUI
import Charts

struct HoleData: Identifiable {
  let id = UUID()
  let details: [Int]
}

struct Histogram: View {
    @State var data : [Int]
    
    var body: some View {
        Chart {
            ForEach(data, id: \.self) { score in
                BarMark(
                    x: .value("", score),
                    y: .value("", total(score: score, in: data))
                    ,width: .fixed(20)
                )
    
                .foregroundStyle(Color("green2"))
                .cornerRadius(5)
            }
        }
        .chartYAxis( .hidden)
        .chartXAxis{
            
            AxisMarks(values: .stride(by: 1)) { value in
                
                
                AxisValueLabel(anchor: .top)
                    .font(.callout)
                
            }
            
        }
        .chartXScale(
            domain: ((data.min() ?? 1) - 1)...((data.max() ?? 8) + 1)
        )
        .frame(width: 150, height: 60)
        .padding()
    }
    
    func total(score: Int, in details: [Int]) -> Int {
        return details.filter{$0 == score}.count
    }
}
#Preview {
    Histogram(data: [7,5,4,5,3,3,5,7,8,4,4,6, 10])
}
