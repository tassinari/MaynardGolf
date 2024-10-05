//
//  PhotoCropper.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/25/24.
//

import SwiftUI


    
struct PhotoCropperViewModel{
    let image: UIImage
}


struct PhotoCropper: View {
    
    
    static var cropRadius : CGFloat = 240
    
    @State var viewModel: PhotoCropperViewModel
    @State private var translation: CGSize = .zero
    @State private var currentAmount = 0.0
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @State private var finalAmount = 1.0
    var body: some View {
       
        ZStack{
            
            Color(.gray)
            Image(uiImage: viewModel.image)
                .scaleEffect(finalAmount + currentAmount)
                .offset(translation)
                .mask() {
                    ZStack{
                        Color.black.opacity(0.2)
                        Color(.black)
                            .frame(width: PhotoCropper.cropRadius, height: PhotoCropper.cropRadius)
                                .clipShape(Circle())
                    }
                }
            
        }
        .navigationTitle("Size your picture")
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    currentAmount = value.magnification - 1
                }
                .onEnded { value in
                    finalAmount += currentAmount
                    currentAmount = 0
                    scale = finalAmount
                   
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged({ v in
                    translation = v.translation
                    offset = CGSize(width: translation.width / 2.0, height: translation.height  / 2.0 )
                })
                

        )
    }
}

#Preview {
    PhotoCropper(viewModel: PhotoCropperViewModel(image: UIImage(named: "phil")!), scale: Binding.constant(0.5), offset: Binding.constant(.zero))
}
