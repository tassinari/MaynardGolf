//
//  Import.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/13/24.
//

import Foundation
import SwiftData
import SwiftUI

struct ActivityURLData :  Identifiable{
    var id : String {
        return url.absoluteString
    }
    var url : URL
}

struct ActivityWrapperView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityWrapperView>) -> UIActivityViewController {
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityWrapperView>) {}
}



enum DatabaseURLType : String, CaseIterable{
    case wal = "default.store-wal"
    case shm = "default.store-shm"
    case db = "default.store"
}

struct ImportExport {
    
    static func databaseURL(type : DatabaseURLType) -> URL{
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let filename = type.rawValue
        return dir.appendingPathComponent(filename)
    }
    ///Makes a zip file in the temporary directoy and returns its URL
    static func zipData() throws -> URL{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let zipFileName = "maynard_golf_archive_" + dateFormatter.string(from: Date())
        let tempDir = FileManager.default.temporaryDirectory
        let zipDir = tempDir.appendingPathComponent(zipFileName, isDirectory: true)
        let archiveUrl: URL = tempDir.appending(component: zipFileName + ".zip")
        let picCopyDir = zipDir.appendingPathComponent("pics")
        try? FileManager.default.createDirectory(at: zipDir, withIntermediateDirectories: true, attributes: nil)
        
        //copy DB over
        for dbtype in DatabaseURLType.allCases {
            let url =  zipDir.appendingPathComponent(dbtype.rawValue)
            if FileManager.default.fileExists(atPath: url.path()){
                //delete if an old copy is there
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.copyItem(at: databaseURL(type: dbtype), to: url)
        }
        
        
        //copy all avatar files
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let d = paths[0]
        let picFolder = d.appending(component: "pics")
        if FileManager.default.fileExists(atPath: picFolder.path){
            try FileManager.default.copyItem(at: picFolder, to: picCopyDir)
        }

        //now zip up zipDIR to a file
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: zipDir, options: [.forUploading], error: nil) { zipUrl in
            try? FileManager.default.copyItem(at: zipUrl, to: archiveUrl)
        }
        return archiveUrl
    }
    
    
    static func zipCSVData() throws -> URL{
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let zipFileName = "maynard_golf_archive_csv_" + dateFormatter.string(from: Date())
        let tempDir = FileManager.default.temporaryDirectory
        let zipDir = tempDir.appendingPathComponent(zipFileName, isDirectory: true)
        let archiveUrl: URL = tempDir.appending(component: zipFileName + ".zip")
        try? FileManager.default.createDirectory(at: zipDir, withIntermediateDirectories: true, attributes: nil)
        
        
        
        let context = ModelContext(MaynardGolfApp.sharedModelContainer)
        let rounds = try context.fetch(FetchDescriptor<Round>())
        for round in rounds{
            let str = round.export()
            FileManager.default.createFile(atPath: zipDir.appendingPathComponent( round.courseID + "-" + round.formattedDateWithTime + ".csv").path, contents: str.data(using: .utf8))
        }
        //now zip up zipDIR to a file
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: zipDir, options: [.forUploading], error: nil) { zipUrl in
            try? FileManager.default.copyItem(at: zipUrl, to: archiveUrl)
        }
        
        return archiveUrl
    }
    
    
    
}


//FIXME: Not ready for primetime, this is just a quick utility to save real data durin development.  Need a real import export feature in future

extension Round{
    
    static func exportData() -> String{
        var roundData = ""
        let context = ModelContext(MaynardGolfApp.sharedModelContainer)
        if let rounds = try? context.fetch(FetchDescriptor<Round>()){
            for round in rounds{
                roundData.append(round.export())
            }
        }
        print(roundData)
        return roundData
    }
    private struct ProtoRound{
        let date : Date
        let data : [[String]]
    }
    static func importData(file : URL){
        //Hackery for now
        do{
            let accessing = file.startAccessingSecurityScopedResource()
                     
             defer {
               if accessing {
                 file.stopAccessingSecurityScopedResource()
               }
             }
            let data = try String(contentsOf: file, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.dateFormat = "h:mm a E MMM d, yyyy"
            var indexes : [Int] = []
            var counts : [Int] = []
            var count : Int = 0
            for (i,line) in lines.enumerated(){
                if let date = dateFormatter.date(from: line){
                    indexes.append(i)
                    if i > 0{
                        counts.append(count)
                        count = 0
                    }
                }else{count += 1}
               
                // let round = Round(date: date)
                
            }
            counts.append(count - 1)
            print(indexes)
            print(counts)
            
            let prounds : [ProtoRound] = indexes.map { i in
                let countindex = indexes.firstIndex(of: i)!
                let date = dateFormatter.date(from: lines[i])
                let data = Array(lines[i+1...i+counts[countindex]])
                var arr : [[String]] = []
                for d in data{
                    arr.append(d.components(separatedBy: [","]))
                }
                return ProtoRound(date: date!, data: arr)
            }
            Self.importRoundds(from: prounds)
        }catch let e{
            print(String(describing: e))
        }
        
        
    }
    static private func importRoundds(from data : [ProtoRound]){
        let context = ModelContext(MaynardGolfApp.sharedModelContainer)
       
        for pr in data{
            let players = try! context.fetch(FetchDescriptor<Player>())
            for str in pr.data{
                if !players.contains(where: { p in
                    p.firstName == str[0]
                }){
                    //make a player
                    let player = Player(firstName: str[0], lastName: "Tassinari", color: .blue, photoPath: nil)
                    context.insert(player)
                    try? context.save()
                }
            }
            let holes =  try! Round.courseData(forCourse: "MaynardGC").holes
            let allplayers = try! context.fetch(FetchDescriptor<Player>())
            //insert round
            var playerrounds : [PersonRound] = []
            for str in pr.data{
                if let p = allplayers.first(where: { p in
                    p.firstName == str[0]
                }){
                    let scores : [Score] = str[1..<str.count].enumerated().map{ Score(hole: holes[$0] , score:Int($1))}
                    playerrounds.append(PersonRound(player: p, score: scores, tee: .white, position: 0))
                }
            }
            
            let round = Round(players: playerrounds, date: pr.date, course: "MaynardGC")
            context.insert(round)
            try? context.save()
        }
    }
    fileprivate func export() -> String{
        /**
            Date, Course, Temp, Weather, Tee, Name, 1,2,3,4,5,6,7,8,9, out
         */
        var str = "Date, Course, Temp, Weather, Tee, Name, 1,2,3,4,5,6,7,8,9, out\n"
        for player in players{
            str.append("\"" + formattedDateWithTime + "\"" + ",")
            str.append(courseID + ",")
            str.append((weatherTemp ?? "-") + ",")
            str.append((weatherString ?? "-") + ",")
            str.append(player.tee.name + ",")
            str.append(player.player.name + ",")
            let scores = player.score.map(\.scoreString).joined(separator: ",")
            str.append(scores + ",")
            str.append(String(player.totalScore) + "\n")
        }
        return str
    }
    
}
