//
//  EasyLoginAuthenticatorTests.swift
//  EasyLogin
//
//  Created by Frank on 31/08/17.
//
//

import XCTest
@testable import DataProvider
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
            let result = UserAuthMethods(id: returnedUser.uuid, authMethods: returnedUser.authMethods!)
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
        ("testInvalidBase64StringReturnsNil", testInvalidBase64StringReturnsNil),
        ("testValidBasicAuthenticationReturnsTuple", testValidBasicAuthenticationReturnsTuple),
    ]
    
    func testEmptyBasicAuthenticationReturnsNil() throws {
        let authenticator = try mockAuthenticator()
        let auth = authenticator.decodeBasicCredentials("Basic ")
        XCTAssertNil(auth)
    }
    
    func testInvalidBase64StringReturnsNil() throws {
        let authenticator = try mockAuthenticator()
        let auth = authenticator.decodeBasicCredentials("Basic whatever_invalid_base64!")
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
        let jsonData = """
        {
            "type": "user",
            "_id": "264E37B0-7F7F-4469-9B85-E5923567C9CF",
            "_rev": "1-xxxxxxx",
            "uuid": "4478B28E-BD6B-43C5-AB4B-D16E95D04FD2",
            "created": "2018-02-09T18:42:42Z",
            "modified": "2018-02-09T18:42:42Z",
            "type": "user",
            "numericID": 1789,
            "shortname": "test",
            "principalName": "test@example.easylogin.cloud",
            "email": "test@easylogin.cloud",
            "fullName": "EasyLogin Test",
            "authMethods": {"pbkdf2": "$pbkdf2-sha512$403225$RLztVE1nadcSiq+4uGfmzXs+gI8i1CNSlDQzTTqAYnI$CmEOEYxAG/0IKx1CX5YGam+ZAqKSPh+Y2L6CNIqgKks"}
        }
        """.data(using: .utf8)!
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        jsonDecoder.userInfo[.managedObjectCodingStrategy] = ManagedObjectCodingStrategy.databaseEncoding
        let user = try jsonDecoder.decode(ManagedUser.self, from: jsonData)
        let provider = MockUserProvider(expectedLogin: "username", returnedUser: user)
        let authenticator = EasyLoginAuthenticator(userProvider: provider)
        return authenticator
    }
}
