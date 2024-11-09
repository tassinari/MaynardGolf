//
//  SwiftUIView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/15/24.
//

import SwiftUI


struct RoundDetailModel{
    
    init(round: Round) throws {
        self.round = round
        self.courseData = try round.coursData
        cardViewModel = try round.cardViewModel
        if round.inProgress{
            roundInProgress = round
        }
    }
    
    var round : Round
    
    var courseName : String{
        return courseData.name
    }
    private let courseData : Course
    let cardViewModel : CardView.ViewModel
    var roundInProgress : Round? = nil
    
    @MainActor func render() -> URL {
        
        //creeate tmp dir
        let tempDir = FileManager.default.temporaryDirectory
        let zipDir = tempDir.appendingPathComponent("pdfExports", isDirectory: true)
        if FileManager.default.fileExists(atPath: zipDir.path(percentEncoded: false)){
            try? FileManager.default.removeItem(at: zipDir)
        }
        try? FileManager.default.createDirectory(at: zipDir, withIntermediateDirectories: true, attributes: nil)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "maynardGolf_\(dateFormatter.string(from: round.date)).pdf"
        let renderer = ImageRenderer(content: PDFView(round: self.round).frame(width: 700, height: 400))
        let url = zipDir.appending(path: filename)
        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else {
                return
            }
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        return url
    }
}

struct RoundDetailView: View {
    @State var model : RoundDetailModel
    
    var body: some View {
        VStack(spacing: 0){
            List(){
                Section(){
                    HStack{
                        Group{
                            VStack(alignment: .leading){
                                Text(model.courseName)
                                    .font(.title2)
                                Text(model.round.formattedDateWithTime)
                                    .font(.callout)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            if let w = model.round.weatherString, let t = model.round.weatherTemp{
                                WeatherView(icon: w, temp: t)
                            }else{
                                EmptyView()
                            }
                        }

                    }
                    .padding([.bottom], 5)
                    .listRowSeparator(.hidden)
                }
                Section(header:
                            HStack(alignment: .bottom){
                    Text("Score Card")
                    Spacer()
                    

                    
                    }
                    .padding([.bottom], 10)
                    .padding()
                            
                ){
                    VerticalCardView(model: VerticalCardViewModel(round: model.round))
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
               
                Section(header: Text("Players")){
                    ForEach(model.round.sortedPlayers){ p in
                        CardPlayerScoreCell(model: CardPlayerScoreCell.ViewModel(player: p.player, score: p.totalScore,toPar: String(p.overUnderString), round: model.round ))
                }
                }
            }
            .listStyle(.plain)
            
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(alignment: .center){
                    Button {
                        model.roundInProgress = model.round
                    } label:{
                        Text("Edit")
                            
                    }
                    .padding(4)
                    ShareLink(item: model.render())
                    .padding(4)
                }
            }
        }
        .fullScreenCover(item: $model.roundInProgress) { round in
            if let model = try? HoleViewContainerModel(round: round){
                HoleViewContainer(model: model)
            }else{
                Text("Error")
            }
            
        }
        
    }
    
}
#if DEBUG
#Preview {
    if let r = MainPreviewData.round, let model = try? RoundDetailModel(round: r){
        NavigationStack {
            RoundDetailView(model: model)
        }
       
    }else{
       Text("Error")
    }
    
}

#endif
