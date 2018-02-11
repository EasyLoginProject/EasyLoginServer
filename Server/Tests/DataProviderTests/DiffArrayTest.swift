//
//  DiffArrayTest.swift
//  EasyLogin
//
//  Created by Frank on 19/01/2018.
//

import XCTest
@testable import EasyLoginDirectoryService

class DiffArrayTest: XCTestCase {
    static var allTests = [
        ("testEmptyArrays", testEmptyArrays),
        ("testEmptyInitial", testEmptyInitial),
        ("testEmptyFinal", testEmptyFinal),
        ("testDisjoint", testDisjoint),
        ("testAddRemove", testAddRemove),
    ]

    func testEmptyArrays() {
        arrayTest(initial:[], final:[], expected:([], []))
    }
    
    func testEmptyInitial() {
        arrayTest(initial:[], final:["a", "b", "c"], expected:(["a", "b", "c"], []))
    }
    
    func testEmptyFinal() {
        arrayTest(initial:["a", "b", "c"], final:[], expected:([], ["a", "b", "c"]))
    }
    
    func testDisjoint() {
        arrayTest(initial:["a", "b"], final:["c"], expected:(["c"], ["a", "b"]))
    }
    
    func testAddRemove() {
        arrayTest(initial:["a", "b"], final:["b", "c"], expected:(["c"], ["a"]))
    }
    
    func arrayTest(initial: [String], final:[String], expected: ([String], [String])) {
        let (added, removed) = final.difference(from: initial)
        XCTAssertEqual(Set(added), Set(expected.0))
        XCTAssertEqual(Set(removed), Set(expected.1))
    }
}
