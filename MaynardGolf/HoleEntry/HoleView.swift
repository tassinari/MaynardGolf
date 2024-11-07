//
//  HoleView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/9/24.
//

import SwiftUI
import SwiftData

struct HoleViewContainer : View{
    @Environment(\.presentationMode) var presentationMode
    @Bindable var model : HoleViewContainerModel
    
    
    var body: some View{
        NavigationStack{
            TabView(selection: $model.selectedHole){
                ForEach(model.holes){ hole in
                    HoleView(model: hole)
                        .tag(hole.hole.number)
                        .onAppear(){
                            hole.refresh()
                        }
                }
            }
            
            .tabViewStyle(.page(indexDisplayMode: .never))
           .sheet(item: $model.completeViewModel) { model in
               RoundCompleteView(viewModel: model)
                       .presentationDetents([.medium])

           }
           .sheet(item: $model.verticalCardViewModel) { model in
                   VerticalCardView(model:model)
                       .presentationDetents([.medium])

           }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack{
                        Button(action:{
                            model.showYardage()
                        },
                        label: {
                            Image(systemName: "flag")
                        }
                        )
                        .padding(.trailing)
                        Button("Card") {
                            model.showCard()
                        }
                    }
                    
                }
            }
        }
        .sheet(item: $model.yardageFinder) { hole in
            YardageFinderContainerView(model: YardageFinderModel(hole: hole))
                .presentationDetents([.medium])
        }
    }
}

struct YardageView : View{
    @Bindable var model :  HoleViewModel
    var body: some View {
        VStack(spacing: 0){
            Group{
                Text(String(model.hole.yardage.blue))
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(.blue)
                
                Text(String(model.hole.yardage.white))
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    
                Text(String(model.hole.yardage.yellow))
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(.yellow)
                Text(String(model.hole.yardage.red))
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(.red)
            }
            .foregroundColor(.black)
        }
        .frame(maxWidth: 80)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}


struct HeaderView : View{
    @Bindable var model :  HoleViewModel
    var body: some View {
        VStack{
            
            HStack(alignment: .top){
                Image(model.hole.holeIconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                    .frame(maxHeight: 530, alignment: .top)
                    //.border(.red)
                    .padding([.leading], 30)
                    
                Spacer()
                VStack{
                    HoleNumberView(number: model.hole.number)
                    VStack(alignment: .center){
                        ParView(number: model.hole.par)
                            .padding()
                        HandicapView(number: model.hole.handicap)
                            .padding(.bottom)
                        YardageView(model: model)
                        
                    }
                }
                .padding([.trailing], 30)
            }
        }
        .padding([.top], 20)
     
       
    }
}

struct ScoreArea : View{
    @Binding var players : [ScoreModel]
    @Binding var entry : ScoreModel?
    var body: some View {
        VStack{
           
            ForEach(players){ pl in
                HStack{
                    Text(pl.overUnder)
                        .font(.title2)
                    Text(pl.player.name)
                        .padding(.leading, 20)
                        .font(.title)
                    Spacer()
                    Button(action: {
                       entry = pl
                    }, label: {
                        Group{
                            if let s = pl.score{
                                if s == 0{
                                    Text("-")
                                }else{
                                    Text(String(s))
                                }
                            }else{
                                Image(systemName: "plus.circle")
                            }
                        }
                        .font(.largeTitle)
                    })
                    
                }
                .padding(.trailing, 20)
                .padding(8)
            }
            
            
            
        }
        
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }
}

struct HoleView: View {
    @Bindable var model :  HoleViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0){
           
            VStack(alignment: .leading){
                HeaderView(model: model)
                
                ScoreArea(players: $model.players, entry: $model.entry)
                    .offset(CGSize(width: 0, height: 0))
            }
            Spacer()
        }
        .sheet(item: $model.entry) { score in
            EntryView(model: EntryView.ViewModel(name: score.player.firstName, hole: score.hole, entry: { sc in
                model.update(player: score.player, score: sc)
                model.entry = nil
            }))
            .background(.clear)
                .presentationDetents([.medium])
        }
        .sheet(item: $model.cardViewModel) { model in
            
                CardView(model:model)
                    .presentationDetents([.medium])
           
            
        }
    }
}
#if DEBUG
#Preview {
    if let r = MainPreviewData.round, let model = try? HoleViewContainerModel(round: r){
        return HoleViewContainer(model: model)
    }else{
        return Text("Error")
    }
}
#endif
