//
//  RoundCompleteView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/3/24.
//

import SwiftUI

struct RoundCompleteViewModel : Identifiable{
    var id : String {round.id}
    var round: Round
}

struct RoundCompleteView: View {
    var viewModel: RoundCompleteViewModel
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        VStack {
            HStack{
                
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.title)
                }
                .padding()
                Text("⛳️ Round Complete").font(.title)
                Spacer()
            }
            VerticalCardView(model: VerticalCardViewModel(round: viewModel.round))
                .presentationDetents([.medium])
            Spacer()
        }
       
    }
}
#if DEBUG
#Preview {
    if let r = MainPreviewData.round{
        RoundCompleteView(viewModel: RoundCompleteViewModel(round: r))
    }else{
        Text("No Data")
    }
    
}
#endif
