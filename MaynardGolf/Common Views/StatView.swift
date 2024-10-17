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
        HStack{
            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)
            Text(stat)
                .font(.title2)
        }
        
        
    }
}

#Preview {
   
    StatView(stat: "41", title: "Best")
        
   
   
}
