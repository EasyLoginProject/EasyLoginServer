//
//  EasyLoginAuthenticatorTests.swift
//  EasyLogin
//
//  Created by Frank on 31/08/17.
//
//

import XCTest
import Extensions
import SwiftyJSON
@testable import Extensions
@testable import Application

struct MockUserProvider: UserRecordProvider {
    let expectedLogin: String
    let returnedUser: ManagedUser
    
    init(expectedLogin: String, returnedUser: ManagedUser) {
        self.expectedLogin = expectedLogin
        self.returnedUser = returnedUser
    }
    
    func userAuthMethods(login: String, callback: @escaping (UserAuthMethods?) -> Void) {
        if login == expectedLogin {
            let result = UserAuthMethods(id: returnedUser.uuid!, authMethods: returnedUser.authMethods)
            callback(result)
        }
        else {
            callback(nil)
        }
    }
}

class EasyLoginAuthenticatorTests: XCTestCase {
    static var allTests = [
        ("testEmptyBasicAuthenticationReturnsNil", testEmptyBasicAuthenticationReturnsNil),
        ("testValidBasicAuthenticationReturnsTuple", testValidBasicAuthenticationReturnsTuple),
    ]
    
    func testEmptyBasicAuthenticationReturnsNil() throws {
        let authenticator = try mockAuthenticator()
        let auth = authenticator.decodeBasicCredentials("Basic ")
        XCTAssertNil(auth)
    }
    
    func testValidBasicAuthenticationReturnsTuple() throws {
        let authenticator = try mockAuthenticator()
        let auth = authenticator.decodeBasicCredentials("Basic dXNlcm5hbWU6cGFzc3dvcmQ=")
        XCTAssertNotNil(auth)
        XCTAssertEqual(auth!.login, "username")
        XCTAssertEqual(auth!.password, "password")
    }
    
    func mockAuthenticator() throws -> EasyLoginAuthenticator {
        let userDict: [String:Any] = ["type":"user",
                                      "_id": "264E37B0-7F7F-4469-9B85-E5923567C9CF",
                                      "uuid":"4478B28E-BD6B-43C5-AB4B-D16E95D04FD2",
                                      "numericID": 1789,
                                      "shortname": "test",
                                      "principalName": "test@example.easylogin.cloud",
                                      "email": "test@easylogin.cloud",
                                      "fullName": "EasyLogin Test",
                                      "authMethods": ["pbkdf2": "$pbkdf2-sha512$403225$RLztVE1nadcSiq+4uGfmzXs+gI8i1CNSlDQzTTqAYnI$CmEOEYxAG/0IKx1CX5YGam+ZAqKSPh+Y2L6CNIqgKks"]
                                      ]
        let userJSON = JSON(userDict)
        let user = try ManagedUser(databaseRecord: userJSON)
        let provider = MockUserProvider(expectedLogin: "username", returnedUser: user)
        let authenticator = EasyLoginAuthenticator(userProvider: provider)
        return authenticator
    }
}
