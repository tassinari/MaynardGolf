//
//  StatView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/10/24.
//

import Foundation
import SwiftUI

struct StatView: View {
    let stat: String
    let title: String
  
    var body: some View {
        ZStack{
            Text(stat)
                .font(.title2)
                .offset(CGSize(width: 0, height: -5))
            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)
                .offset(CGSize(width: 0, height: 15))
        }
        .frame(width: 80, height: 80)
        .background(
           Circle()
            .foregroundStyle(Color(.systemGray6))
             .padding(4)
         )
        
    }
}

#Preview {
   
    StatView(stat: "41", title: "Best")
        
   
   
}
