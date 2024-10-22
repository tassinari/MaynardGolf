//
//  Import.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/13/24.
//

import Foundation
import SwiftData


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
                    playerrounds.append(PersonRound(player: p, score: scores, tee: .white))
                }
            }
            
            let round = Round(players: playerrounds, date: pr.date, course: "MaynardGC")
            context.insert(round)
            try? context.save()
        }
    }
    private func export() -> String{
        var str = formattedDateWithTime + "\n"
        for player in players{
            str.append(player.player.firstName + ",")
            let scores = player.score.map(\.scoreString).joined(separator: ",")
            str.append(scores + "\n")
        }
        return str
    }
    
}
