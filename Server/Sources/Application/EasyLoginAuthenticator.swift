//
//  EasyLoginAuthenticator.swift
//  EasyLogin
//
//  Created by Frank on 30/08/17.
//
//

import Foundation
import Kitura
import Extensions

class EasyLoginAuthenticator: RouterMiddleware {
    let userProvider: UserRecordProvider
    
    init(userProvider: UserRecordProvider) {
        self.userProvider = userProvider
    }
    
    func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        defer {
            next()
        }
        guard let (login, password) = basicCredentials(request: request) else {
            request.userInfo["EasyLoginAuthorization"] = AuthorizationNone(reason: "missing authentication") // TODO: 4xx code
            return
        }
        guard let user = userProvider.user(login: login) else {
            request.userInfo["EasyLoginAuthorization"] = AuthorizationNone(reason: "user not found")
            return
        }
        print ("check \(user) password \(password)")
        request.userInfo["EasyLoginAuthorization"] = AuthorizationNone(reason: "not implemented... yet")
    }
    
    func basicCredentials(request: RouterRequest) -> (login: String, password: String)? {
        guard let authorizationHeader = request.headers["Authorization"] else { return nil }
        return decodeBasicCredentials(authorizationHeader)
    }
    
    func decodeBasicCredentials(_ authorizationHeader: String) -> (login: String, password: String)? {
        let authorizationComponents = authorizationHeader.components(separatedBy: " ")
        guard authorizationComponents.count >= 2 else { return nil }
        guard authorizationComponents[0] == "Basic" else { return nil }
        let encodedCredentials = authorizationComponents[1]
        guard let credentialsData = Data(base64Encoded: encodedCredentials) else { return nil }
        guard let decodedCredentials = String(data: credentialsData, encoding: .utf8) else { return nil }
        guard let separatorRange = decodedCredentials.range(of: ":") else { return nil }
        let login = decodedCredentials.substring(to: separatorRange.lowerBound)
        let password = decodedCredentials.substring(from: separatorRange.upperBound)
        return (login, password)
    }
}

extension RouterRequest {
    public func authorization() -> Authorization { // TODO: var, get, set
        return self.userInfo["EasyLoginAuthorization"] as! Authorization
    }
}

struct AuthorizationNone: Authorization {
    let reason: String
    
    init(reason: String) {
        self.reason = reason
    }
    
    func canCreate(_ type: String) -> AuthorizationResult {
        return .denied(reason: reason)
    }
    
    func canRead(field: String, from record: PersistentRecord) -> AuthorizationResult {
        return .denied(reason: reason)
    }
    
    func canUpdate(field: String, from record: PersistentRecord) -> AuthorizationResult {
        return .denied(reason: reason)
    }
    
    func canDelete(_ record: PersistentRecord) -> AuthorizationResult {
        return .denied(reason: reason)
    }
}