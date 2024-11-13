//
//  RuleView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 11/13/24.
//

import SwiftUI

struct RuleView: View {
    @Environment(\.presentationMode) var presentationMode
    let rules: [String] = [
            "USGA Rules govern play unless amended by local rules.",
            "OUT OF BOUNDS: Parking lot, off club property defined by white stakes.",
            "Ball coming to rest in a bark mulch area may be lifted and dropped one club length, no nearer the hole, with no penalty.",
            "All service roads, cart paths, fairway drainage ditches, and protective fences, free lift to nearest point of relief, no nearer the hole.",
            "Ball coming to rest in the confines of a rock or rocks through the green may be moved one club length without penalty.",
            "Players not holding their places on golf course must allow other groups to play through.",
            "Players on 1st tee must alternate with players coming off 9th green.",
            "Do not climb face of bunkers. Rake bunkers and return rake to inside the bunker.",
             "Keep all carts off aprons and greens.",
             "Repair ball marks on green. Replace divots.",
             "Please speed up play.",
             "Maynard Golf Course is a soft spike facility."
        ]
    
    var body: some View {
        VStack(alignment: .leading){
            HStack{
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Close")
                }
                .padding()
           Spacer()

            }
            HStack{
                Spacer()
            Text("Local Rules")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            List(){
                ForEach(rules, id: \.self){ rule in
                    HStack(alignment: .top, spacing: 0){
                        Text("•")
                        Text(rule)
                            .font(.body)
                            .padding([.leading], 10)
                            
                    }
                        
                }
                .listRowSeparator(.hidden)
                
            }
           
            .listStyle(.plain)
            
            Spacer()
        }
    }
}

#Preview {
    RuleView()
}
