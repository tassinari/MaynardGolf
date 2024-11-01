//
//  YardageFinderView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/20/24.
//

import SwiftUI
import CoreLocation

@Observable class YardageFinderModel{
    init(hole: Hole) {
        self.hole = hole
        self.location = Location()
        
        //need to be careful of retain cycle in callback
        location.callback = { [weak self]  arr in
                self?.receiveLocation(arr)
        }
        location.requestLocation()
    }
    let location : Location
    let hole : Hole
    
    var distanceToFront : String? = nil
    var distanceToBack : String? = nil
    var distanceToCenter : String? = nil
    var error : String? = nil
    var errorColor : Color = .red
    
    private func yardage(coord : Coordinate, pos : CLLocation) -> Double{
        let green = CLLocation(latitude: coord.lattitude, longitude: coord.longitude)
        return yards(meters: green.distance(from: pos))
    }
    
    private func receiveLocation(_ location: CLLocation){ 
        let distanceToFrontYd = yardage(coord: hole.greenCoordinates.front, pos: location)
        let distanceToCenterYd = yardage(coord: hole.greenCoordinates.center, pos: location)
        let distanceToBackYd = yardage(coord: hole.greenCoordinates.back, pos: location)
        
        self.distanceToFront = String(format: "%.0f", distanceToFrontYd)
        self.distanceToBack = String(format: "%.0f", distanceToBackYd)
        self.distanceToCenter = String(format: "%.0f", distanceToCenterYd)
        self.error = String(format: "%.2f", yards(meters: location.horizontalAccuracy))
        switch location.horizontalAccuracy{
        case 0..<5.0:
            errorColor = .green
        case 5.0..<8.0:
            errorColor = .yellow
        case 8.0..<10.0:
            errorColor = .orange
        default : self.errorColor = .red
    
        }
    }
   
    private func yards(meters: Double) -> Double{
        return meters * 1.0936133
    }
    
    var attributedHole : AttributedString{
        var suffix = "th"
        switch hole.number{
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
        var str = AttributedString(String(hole.number))
        str.font = .title
        return str + superscript
        
    }
}

struct YardageFinderView: View {
    @Environment(\.presentationMode) var presentationMode
    var model : YardageFinderModel
    var body: some View {
        VStack{
            HStack{
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .font(.title)
                .padding()

               
                Spacer()
            }
            Text("\(model.attributedHole) Green")
                .font(.title)
                .padding()
            VStack(spacing: 20){
               
                HStack{
                    Text("Front:")
                        .font(.title2)
                        .fontWeight(.thin)
                    Spacer()
                    Text(model.distanceToFront ?? "--")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("yards")
                        .font(.title2)
                        .fontWeight(.thin)
                       
                }
                HStack{
                    Text("Center:")
                        .font(.title2)
                        .fontWeight(.thin)
                    Spacer()
                    Text(model.distanceToCenter ?? "--")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("yards")
                        .font(.title2)
                        .fontWeight(.thin)
                       
                }
                HStack{
                    Text("Back:")
                        .font(.title2)
                        .fontWeight(.thin)
                    Spacer()
                    Text(model.distanceToBack ?? "--")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("yards")
                        .font(.title2)
                        .fontWeight(.thin)
                       
                }
                HStack(alignment: .lastTextBaseline){
                    Text("+/-")
                        .fontWeight(.thin)
                        .offset(x:0, y: -7)
                    Text(model.error ?? "--")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(model.errorColor)
                    Text("yards")
                        .fontWeight(.thin)
                      
                }
                
            }
            .padding([.leading, .trailing], 100)
            Spacer()
        }
    }
}
#if DEBUG
#Preview {
    Color.white.sheet(isPresented: Binding<Bool>.constant(true)){
        YardageFinderView(model: YardageFinderModel(hole: MainPreviewData.exampleHole))
            .presentationDetents([.medium])
    }
}
#endif
