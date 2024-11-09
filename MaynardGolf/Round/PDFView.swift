//
//  PDFView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 11/8/24.
//

import SwiftUI

struct PDFView: View {
    @State var round : Round
    var body: some View {
        VStack{
            HStack{
                Text("Maynard Golf Club")
                    .fontWeight(.semibold)
                    .padding(.leading, 5)
                    .padding(3)
                Spacer()
                Text(round.formattedDate)
                    .font(.caption)
                    .padding(.leading, 5)
                    .padding(3)
            }
            roundView
                
        }
       
        
        
    }
    @ViewBuilder
    var roundView: some View{
        if let r = try? round.cardViewModel{
            CardView(model: r)
        }else{
            Text("An error occured")
        }
    }
    
    
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        if let r = MainPreviewData.round{
            PDFView(round: r)
                .previewLayout(.fixed(width: 800, height: 350))
                
        }else{
           Text("Error")
        }
    }
    
}

#endif

