//
//  HoleViewModel.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/27/24.
//

import Foundation
import SwiftData


struct ScoreModel : Identifiable{
    var id : String { return player.name}
    let player : Player
    let score : Int?
    let hole : Int
    let overUnder : String

}
extension Notification.Name{
    public static let refreshListener = Notification.Name("refreshListenerNotification")
}
@Observable class HoleViewModel : Hashable, Identifiable{
    
    var id : String { return round.id + String(hole.number)}
    static func == (lhs: HoleViewModel, rhs: HoleViewModel) -> Bool {
        lhs.round.id == rhs.round.id && lhs.hole.number == rhs.hole.number
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(round.id)
        hasher.combine(hole.number)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    init(round : Round, hole: Int = 1) throws{
        self.round = round
        guard let hl = try round.coursData.holes.first(where: {$0.number == hole}) else{
            throw DataError.holeNotFound
        }
        self.hole = hl
        self.players = []
        self.handler = handler
        refresh()
        let nc = NotificationCenter.default.addObserver(forName: Notification.Name.refreshListener, object: nil, queue: nil) { [weak self ] note in
            self?.refresh()
        }
    }
    var entry : ScoreModel? = nil
    var hole : Hole
    private let round : Round
    var players : [ScoreModel]
    var handler :  ((Int) -> Void)?
    var cardViewModel : CardView.ViewModel?

    func refresh() {
        let pls = try? round.cardOrder.map({ pr in
            let i = pr.score.firstIndex { sc in
                sc.hole.number == hole.number
            }
        
            guard let i else {
                throw DataError.holeNotFound
            }
            return ScoreModel(player: pr.player, score: pr.score[i].score, hole: pr.score[i].hole.number, overUnder: pr.overUnderString)
        })
        if let pls{
            self.players = pls
        }
       
    }
    func update(player: Player, score: Int?) {
        
        //update round
        let pr = round.players.first { pr in
            pr.player == player
        }
        if let pr,  let index = pr.score.firstIndex(where: {$0.hole.number == hole.number}){
            pr.score[index] = Score(hole: hole, score: score)
        }
        
        self.players = players.map { sm in
            if sm.player == player{
                return ScoreModel(player: player, score: score, hole: sm.hole, overUnder: pr?.overUnderString ?? "-")
            }
            return sm
        }
        Task{ @MainActor in
            round.complete = round.scoresFilledIn
            try? MaynardGolfApp.sharedModelContainer.mainContext.save()
            NotificationCenter.default.post(name: Notification.Name.refreshListener, object: nil)
        }
    }
}

@Observable class HoleViewContainerModel{
    
    var verticalCardViewModel : VerticalCardViewModel? = nil
    var yardageFinder : Hole? = nil
    init(round: Round) throws {
        self.round = round
        var models : [HoleViewModel] = []
        for i in 1...9{
            let model = try HoleViewModel(round: round, hole: i)
            models.append(model)
        }
        holes = models
        selectedHole = round.nextHole
        if round.scoresFilledIn{
            selectedHole = 9
            completeViewModel = RoundCompleteViewModel(round: round)
        }
       
    }
    var selectedHole : Int
    var holes : [HoleViewModel] = []
    //var holeView : HoleViewType
    private let round : Round
    var completeViewModel : RoundCompleteViewModel? = nil
    
    func showCard(){
        verticalCardViewModel = VerticalCardViewModel(round: self.round)

    }
    func showYardage(){
        let model = holes[selectedHole - 1]
        yardageFinder = model.hole
    }
}
