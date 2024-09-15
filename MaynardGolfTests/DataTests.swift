//
//  DataTests.swift
//  MaynardGolfTests
//
//  Created by Mark Tassinari on 9/11/24.
//

import XCTest
import SwiftData
@testable import MaynardGolf

final class DataTests: XCTestCase {
    var context : ModelContext!
    
    override func setUp() async throws {
        
        let container = try ModelContainer(for: Player.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
    }
    
    
    func testJSONParses() throws {
        let bundle = Bundle(for: Player.self )
        guard let path = bundle.url(forResource: "MaynardGC", withExtension: "json") else { XCTFail("No data"); return}
        let data = try Data(contentsOf: path)
        let course = try JSONDecoder().decode( Course.self, from: data)
        XCTAssert(course.holes.count > 0)
        XCTAssert(course.holes.first?.par == 4)
        XCTAssert(course.holes.first?.yardage.blue == 100)
        
    }
    
    func testPlayerSaveInit() throws {
        let name = "Mark"
        let p = Player(name: name)
        context.insert(p)
        
        
        let fetch = FetchDescriptor<Player>()
        guard let model = try context.fetch(fetch).first else {XCTFail() ; return}
        XCTAssert(model.name == name)
    }
        
}
