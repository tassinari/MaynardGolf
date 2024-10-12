//
//  ScoreMarker.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/11/24.
//

import SwiftUI

enum ScoreName{
    case doubleEagle, eagle, birdie, par, bogey, doubleBogey, tripleBogey, other, invalid
    
    var description : String{
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
    static func name(par: Int, score: Int) -> ScoreName{
        if score == 0{ return .invalid }
        switch score{
        case 1:
            switch par{
            case 3: return .eagle
            case 4: return .doubleEagle
            case 5: return .other
            default: return .other
            }
        case 2:
            switch par{
            case 3: return .birdie
            case 4: return .eagle
            case 5: return .doubleEagle
            default: return .birdie
            }
        case 3:
            switch par{
            case 3: return .par
            case 4: return .birdie
            case 5: return .eagle
            default: return .bogey
            }
        case 4:
            switch par{
            case 3: return .bogey
            case 4: return .par
            case 5: return .birdie
            default: return .par
            }
        case 5:
            switch par{
            case 3: return .doubleBogey
            case 4: return .bogey
            case 5: return .par
            default: return .bogey
            }
        case 6:
            switch par{
            case 3: return .tripleBogey
            case 4: return .doubleBogey
            case 5: return .bogey
            default: return .bogey
            }
        case 7:
            switch par{
            case 3: return .other
            case 4: return .tripleBogey
            case 5: return .doubleBogey
            default: return .tripleBogey
            }
        case 8:
            switch par{
            case 3: return .other
            case 4: return .other
            case 5: return .tripleBogey
            default: return .other
            }
        
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
                //GeometryReader { geometry in
                    ZStack(alignment: .center) {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1))
                            .aspectRatio(1.0, contentMode: .fit)
                           
                            
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1))
                            .aspectRatio(1.0, contentMode: .fit)
                            .frame(width: 18)
                            
                 //   }
                }
                    
            )
    }
}
struct OtherMarker: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(
                //GeometryReader { geometry in
                    ZStack(alignment: .center) {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(.red)
                            .aspectRatio(1.0, contentMode: .fit)
                           
                            
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(.red)
                            .aspectRatio(1.0, contentMode: .fit)
                            .frame(width: 18)
                            
                 //   }
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
            modifier(OtherMarker())
        }
    }
}
