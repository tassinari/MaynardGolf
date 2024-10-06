//
//  PlayerTileView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/18/24.
//

import SwiftUI
import SwiftData


struct PlayerImage : View {
    var imageRadius : CGFloat = 60
    @State var player  : Player
    let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    var body: some View {
        Group{
            if
                let path = player.photoPath,
                let data = try? Data(contentsOf: docDir.appendingPathComponent(path)),
               let image = UIImage(data: data)
            {
                Image(uiImage: image)
                    .scaleEffect(player.scale * (imageRadius / PhotoCropper.cropRadius))
                    .offset(modifiedOffset)
                   
                    
            }else{
                ZStack{
                    Color(.systemGray6)
                    Text("\(player.firstName.first?.uppercased() ?? "")\(player.lastName.first?.uppercased() ?? "")")
                        .font(.title2)
                        .foregroundStyle(.gray)
                        .fontWeight(.bold)
                }
               
            }
        }
        .frame(width: imageRadius, height: imageRadius)
            .aspectRatio(contentMode: .fit)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(player.color.color, lineWidth: 4)
            }
    }
    var modifiedOffset : CGSize {
      
        CGSize(width: player.offset.width * ( (imageRadius / PhotoCropper.cropRadius) * 2), height: player.offset.height * ((imageRadius / PhotoCropper.cropRadius) * 2))
    }
}
@Observable class PlayerTileViewModel{
    internal init(player: Player) {
        self.player = player
        Task {
            if let avgs = await player.maxMinScores{
                self.min = avgs.1
                self.max = avgs.0
                self.avg = avgs.2
            }
            hc = await player.handicap
        }
        self.hc = nil
    }
    
    let player : Player
    var min : Int? = nil
    var max : Int? = nil
    var avg : Double? = nil
    var hc : Double?
}

struct PlayerTileView: View {
    let model  : PlayerTileViewModel
    var body: some View {
        VStack{
            HStack(alignment: .top) {
                PlayerImage(player: model.player)
                    .padding([.trailing], 5)
                    
                VStack(alignment: .leading) {
                    HStack{
                        Text(model.player.name)
                            .font(.title2)
                        Spacer()
                        if let hc = model.hc{
                            Text(String(format:"%.1f",hc))
                                .foregroundStyle(.white)
                                .frame(width: 55, height: 55)
                                .background(
                                   Circle()
                                    .foregroundColor(Color("green2"))
                                     .padding(4)
                                 )
                        }
                    }
                    if let min = model.min, let max = model.max , let avg = model.avg{
                        Gauge(value: avg, in: Double(min)...Double(max)) {}
                   currentValueLabel: {
                                      Text(Int(avg), format: .number)
                                  } minimumValueLabel: {
                                      Text(String(min))
                                          .font(.caption)
                                          
                                  } maximumValueLabel: {
                                      Text(String(max))
                                          .font(.caption)
                                  }
                                  .padding([.trailing], 60)
                                  .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
                                  .gaugeStyle(.accessoryLinear)
                    }
                               

                    
                              
                }
               
               
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        
        .padding()
        .background(
            Color("green1").opacity(0.2)
                
        )
        .cornerRadius(20)
        .shadow(color: .gray.opacity(0.4), radius: 2, x: 0, y: 0)
        
        .padding([.leading, .trailing], 10)
        
    }
}

#Preview {
    if let p = try? ModelContext(PlayerPreviewData.previewContainer).fetch(FetchDescriptor<Player>()).first {
        PlayerTileView(model: PlayerTileViewModel(player: p)).border(Color.red, width: 1)
    }else{
        Text("No Preview")
    }
}
#Preview("Image"){
    if let p = try? ModelContext(PlayerPreviewData.previewContainer).fetch(FetchDescriptor<Player>()).first {
        return PlayerImage(player: p)
    }else{
        return Text("No Preview")
    }
}
