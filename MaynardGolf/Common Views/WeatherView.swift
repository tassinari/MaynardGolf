//
//  WeatherView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/12/24.
//

import SwiftUI


struct WeatherView: View {
    
    var icon : String
    var temp : String
    var body: some View {
        HStack{
            Image(systemName: icon)
            Text(temp)
        }
        .font(.title2)
        .foregroundStyle(.black)
        .fontWeight(.thin)
        
       
    }
}

#Preview {
    WeatherView(icon: "cloud.sun", temp: "65°F")
}
