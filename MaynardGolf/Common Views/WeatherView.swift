//
//  WeatherView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/12/24.
//

import SwiftUI

extension WeatherView{
    @Observable class ViewModel{
        init(){
            Task{@MainActor in
                self.temp = try await WeatherReporter.shared.temperature
                self.icon = try await WeatherReporter.shared.icon
            }
        }
        
        var temp : String? = nil
        var icon : String? = nil
    }
}

struct WeatherView: View {
    var viewModel : ViewModel =  ViewModel()
    var body: some View {
        HStack{
            if let icon = viewModel.icon{
                Image(systemName: icon)
                  
            }
           if let temp = viewModel.temp{
               Text(temp)
            }
            
            
        }
        .font(.title2)
        .foregroundStyle(.black)
        .fontWeight(.thin)
        
       
    }
}

#Preview {
    WeatherView()
}
