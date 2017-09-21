//
//  EasyLoginAuthenticatorTests.swift
//  EasyLogin
//
//  Created by Frank on 31/08/17.
//
//

import XCTest
@testable import Application

class EasyLoginAuthenticatorTests: XCTestCase {
    func testEmptyBasicAuthenticationReturnsNil() throws {
        let auth = EasyLoginAuthenticator.decodeBasicCredentials("Basic ")
        XCTAssertNil(auth)
    }
    
    func testValidBasicAuthenticationReturnsTuple() throws {
        let auth = EasyLoginAuthenticator.decodeBasicCredentials("Basic dXNlcm5hbWU6cGFzc3dvcmQ=")
        XCTAssertNotNil(auth)
        XCTAssertEqual(auth!.login, "username")
        XCTAssertEqual(auth!.password, "password")
    }
}
