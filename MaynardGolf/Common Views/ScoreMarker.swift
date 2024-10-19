//
//  ScoreMarker.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/11/24.
//

import SwiftUI

enum ScoreName : Int, Hashable, Comparable{
    static func < (lhs: ScoreName, rhs: ScoreName) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    case doubleEagle, eagle, birdie, par, bogey, doubleBogey, tripleBogey, other, invalid
    
    var name : String{
        switch self{
        case .invalid: return "-"
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
    var shortName : String{
        switch self{
        case .invalid: return "-"
        case .doubleEagle: return "D.E."
        case .eagle: return "Eagle"
        case .birdie: return "Birdie"
        case .par: return "Par"
        case .bogey: return "Bogey"
        case .doubleBogey: return "Double"
        case .tripleBogey: return "Triple"
        case .other: return "Other"
        }
    }
    static func name(par: Int, score: Int) -> ScoreName{
        if score == 0{ return .invalid }
        let diff = par - score
        switch diff{
        case -3: return .tripleBogey
        case -2: return .doubleBogey
        case -1: return .bogey
        case 0: return .par
        case 1: return .birdie
        case 2: return .eagle
        case 3: return .doubleEagle
        default: return .other
        }
    }
}


struct BirdieMarker: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(
                Circle().stroke(style: StrokeStyle(lineWidth: 1))
                    
            )
    }
}
struct EagleMarker: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(
                ZStack(alignment: .center) {
                    Circle().stroke(style: StrokeStyle(lineWidth: 1))
                    Circle().stroke(style: StrokeStyle(lineWidth: 1))
                        .frame(width: 18)
                }
            )
    }
}
struct DoubleBogieMarker: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(
                GeometryReader { geometry in
                    ZStack(alignment: .center) {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1))
                            .offset(x: 0,y: (geometry.size.height - geometry.size.width) / 2)
                            .frame(width: geometry.size.width, height: geometry.size.width )
                           
                            
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1))
                            .offset(x: 0,y: (geometry.size.height - geometry.size.width) / 2)
                            .frame(width: geometry.size.width - 4, height: geometry.size.width - 4 )
                    }
                }
            )
    }
}
struct OtherMarker: ViewModifier {
    var color : Color = .black
    var doubleDigit : Bool = false
    func body(content: Content) -> some View {
        content
            .padding(doubleDigit ? 3 : 6)
            .background(
                GeometryReader { geometry in
                    ZStack(alignment: .center) {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(color)
                            .offset(x: 0,y: (geometry.size.height - geometry.size.width) / 2)
                            .frame(width: geometry.size.width, height: geometry.size.width )
                           
                            
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(color)
                            .offset(x: 0,y: (geometry.size.height - geometry.size.width) / 2)
                            .frame(width: geometry.size.width - 4, height: geometry.size.width - 4 )

                    }
                }
            )
    }
}
struct BogieMarker: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1))
                    .aspectRatio(1.0, contentMode: .fit)
            )
    }
}
struct NoMarker: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(6)
    }
}

extension View {
    @ViewBuilder
    func scoreMark(_ score : Int, par : Int) -> some View {
       
        switch ScoreName.name(par: par, score: score) {
        case .invalid:
            modifier(NoMarker())
        case .birdie:
            modifier(BirdieMarker())
        case .doubleEagle:
            modifier(EagleMarker())
        case .eagle:
            modifier(EagleMarker())
        case .par:
            modifier(NoMarker())
        case .bogey:
            modifier(BogieMarker())
        case .doubleBogey:
            modifier(DoubleBogieMarker())
        case .tripleBogey:
            modifier(OtherMarker())
        case .other:
            modifier(OtherMarker(color: .red, doubleDigit: score > 9))
        }
    }
}
