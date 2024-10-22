//
//  TeeSelectorView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/21/24.
//

import SwiftUI


struct TeeSelectorView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var name: String
    @Binding var tee : Tee
    var body: some View {
        VStack{
            HStack{
                Text("Choose Tees for")
                Text(name)
                    .fontWeight(.bold)
            }
            .padding([.bottom])
            HStack{
                Button {
                    tee = .blue
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Blue")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                      .frame(width: 80, height: 80)
                      .background(.blue)
                      .clipShape(Circle())
                      .padding()
                }
                Button {
                    tee = .white
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("White")
                        .font(.title3)
                        .foregroundStyle(.black)
                        .fontWeight(.bold)
                      .frame(width: 80, height: 80)
                      .background(
                        Circle()
                            .fill(.white)
                            .stroke(.black, lineWidth: 1)
                      )
                }
                .padding()
            }
            HStack{
                Button {
                    tee = .yellow
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Yellow")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                      .frame(width: 80, height: 80)
                      .background(.yellow)
                      .clipShape(Circle())
                      .padding()
                }
                Button {
                    tee = .red
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Red")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                      .frame(width: 80, height: 80)
                      .background(.red)
                      .clipShape(Circle())
                      .padding()
                }
            }
        }
        
    }
}

#Preview {
    TeeSelectorView(name: "Henry", tee: Binding<Tee>.constant(.white))
}
