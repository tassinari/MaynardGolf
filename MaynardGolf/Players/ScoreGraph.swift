//
//  ScoreGraph.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/22/24.
//

import SwiftUI
import Charts

struct ScoreData: Identifiable, Equatable{
    static func == (lhs: ScoreData, rhs: ScoreData) -> Bool {
        lhs.order == rhs.order
    }
    let id = UUID()
    let date: Date
    let order: Int
    let score: Int
}
@Observable class ScoreGraphModel{
    internal init(player: Player) {
        self.player = player
        self.yScale = 0...0
        Task{@MainActor in
            if let d = await player.scoreGraphData{
                data = d.enumerated().map({ i, tup in
                    return ScoreData(date: tup.0, order: i, score: tup.1 )
                })
                if  let min = data.map({$0.score}).min(), let max = data.map({$0.score}).max(){
                    yScale = (min - 3)...(max + 3)
                }
            }
           
        }
       
    }
    var data : [ScoreData] = []
    let player : Player
    var yScale : ClosedRange<Int>
    var max : Int  { return data.map{$0.score}.max() ?? 0}
    var mid : Double {
        if data.count == 0 { return 0 }
        return Double(data.map{$0.score}.reduce(0, +)) / Double(data.count)
    }
    var min : Int { return data.map{$0.score}.min() ?? 0}
    
    var minIndex : ScoreData?{
        return data.last(where: {$0.score == self.min})
    }
    var maxIndex : ScoreData?{
        return data.last(where: {$0.score == self.max})
    }
    
    var bestString : String {
        guard let item = minIndex else {
            return ""
        }
        let formatted = DateFormatter()
        formatted.dateFormat = "MM/dd"
        return String(String(item.score) + " on "  + formatted.string(from: item.date))
    }
    var worstString : String {
        guard let item = maxIndex else {
            return ""
        }
        let formatted = DateFormatter()
        formatted.dateFormat = "MM/dd"
        return String(String(item.score) + " on "  + formatted.string(from: item.date))
    }
    
    
}

struct ScoreGraph: View {
    var model : ScoreGraphModel
    var body: some View {
        VStack {
            Chart {
                ForEach(model.data) { item in
                    LineMark(
                        x: .value("", item.order),
                        y: .value("Score", item.score)
                    )
                    if item == model.maxIndex {
                        PointMark(
                            x: .value("", item.order),
                            y: .value("", item.score)
                        )
                        .foregroundStyle(.red)
                        .annotation(position: .top,
                                    spacing: 8) {
                            Text(model.worstString)
                                .foregroundStyle(.gray)
                                .font(.caption)
                        }
                    }
                    if item == model.minIndex {
                        PointMark(
                            x: .value("", item.order),
                            y: .value("", item.score)
                        )
                        .foregroundStyle(.green)
                        .annotation(position: .bottom,
                                   
                                    spacing: 8) {
                            Text(model.bestString)
                                .foregroundStyle(.gray)
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYScale(domain: model.yScale)
            .chartYAxis {
                AxisMarks(values: [model.mid]){ vlue in
                    AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 1.0, dash: [5,5]))
                    AxisValueLabel() {
                        Text(String(format:"%.1f",model.mid))
                            .padding([.leading])
                    }
                }
            }
            .chartXAxis(content: {
            })
            .padding()
            .frame( height:100)
        }
    }
}
#if DEBUG
#Preview {
    ScoreGraph(model: ScoreGraphModel(player: MainPreviewData.examplePlayer))
}
#endif
