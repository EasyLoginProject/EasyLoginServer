//
//  PBKDF2Tests.swift
//  EasyLogin
//
//  Created by Frank on 26/07/17.
//
//

import XCTest
import Extensions

class PBKDF2Tests: XCTestCase {
    func testCallsWithSamePasswordGenerateDifferentHashes() throws {
        let p = PBKDF2()
        let s1 = try p.generateString(fromPassword: "password")
        let s2 = try p.generateString(fromPassword: "password")
        XCTAssertNotEqual(s1, s2)
    }
    
    func testModularStringHasFiveComponents() throws {
        let p = PBKDF2()
        let modularString = try p.generateString(fromPassword: "password")
        let components = modularString.components(separatedBy: CharacterSet(charactersIn: "$"))
        XCTAssertEqual(components.count, 5)
    }
    
    func testVerify() throws {
        let p = PBKDF2()
        let modularString = try p.generateString(fromPassword: "password")
        let verified = PBKDF2.verifyPassword("password", withString: modularString)
        XCTAssertTrue(verified)
        let incorrect = PBKDF2.verifyPassword("whatever", withString: modularString)
        XCTAssertFalse(incorrect)
    }
}
