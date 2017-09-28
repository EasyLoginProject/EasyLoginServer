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
        guard let (login, password) = basicCredentials(request: request) else {
            request.userInfo["EasyLoginAuthorization"] = AuthorizationNone(reason: "missing authentication") // TODO: 4xx code
            next()
            return
        }
        userProvider.userAuthMethods(login: login) {
            authMethods in
            guard
                let authMethods = authMethods,
                let modularString = authMethods.authMethods["pbkdf2"]
            else {
                request.userInfo["EasyLoginAuthorization"] = AuthorizationNone(reason: "user not found")
                next()
                return
            }
            let valid = PBKDF2.verifyPassword(password, withString: modularString)
            print ("password valid: \(valid)")
            next()
        }
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
