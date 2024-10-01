//
//  HoleNumberView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/12/24.
//

import SwiftUI

struct HoleNumberView: View {
    let number : Int
    var body: some View {
        ZStack{
            Group{
                Text(String(number))
                    . font(. system(size: 64))
                Text("HOLE")
                    .font(.caption)
                    .offset(CGSize(width: 0, height: 35))
            }
            .offset(CGSize(width: 0, height: -5))
            
            .foregroundStyle(Color("green4"))
            .fontWeight(.bold)
            
        }
       
            .frame(width: 120, height: 120)
            .background(
               Circle()
                 .stroke(Color("green4"), lineWidth: 10)
                 .padding(4)
             )
        
    }
}
struct ParView: View {
    let number : Int
    var body: some View {
        ZStack{
            Group{
                Text(String(number))
                    . font(. system(size: 32))
                Text("PAR")
                    .font(.caption)
                    .offset(CGSize(width: 0, height: 20))
            }
            .offset(CGSize(width: 0, height: -3))
            .foregroundStyle(.white)
            .fontWeight(.bold)
        }
       
            .frame(width: 80, height: 80)
            .background(
               Circle()
                .foregroundColor(Color("green3"))
             )
        
    }
}
#Preview {
    VStack{
        HoleNumberView(number: 5)
        ParView(number: 3)
        
    }
    .background(Color(.systemGray6))
   
}
