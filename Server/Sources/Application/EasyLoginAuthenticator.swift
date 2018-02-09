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
import DataProvider

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
                request.userInfo["EasyLoginAuthorization"] = AuthorizationNone(reason: "invalid login or password") // TODO: 4xx code, stop processing
                next()
                return
            }
            let valid = PBKDF2.verifyPassword(password, withString: modularString)
            print ("password valid: \(valid)")
            if (valid) {
                if (login == "admin") { // TODO: define admin role
                    request.userInfo["EasyLoginAuthorization"] = AuthorizationAll()
                }
                else {
                    request.userInfo["EasyLoginAuthorization"] = AuthorizationForUser(id: authMethods.id)
                }
            }
            else {
                request.userInfo["EasyLoginAuthorization"] = AuthorizationNone(reason: "invalid login or password") // TODO: 4xx code, stop processing
            }
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
        let credentialsComponents = decodedCredentials.split(separator: ":", maxSplits: 1)
        guard credentialsComponents.count == 2 else { return nil }
        let login = String(credentialsComponents[0])
        let password = String(credentialsComponents[1])
        return (login, password)
    }
}

extension RouterRequest {
    public var easyLoginAuthorization: Authorization {
        get {
            return userInfo["EasyLoginAuthorization"] as! Authorization
        }
        set {
            userInfo["EasyLoginAuthorization"] = newValue
        }
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

struct AuthorizationAll: Authorization {
    func canCreate(_ type: String) -> AuthorizationResult {
        return .granted
    }
    
    func canRead(field: String, from record: PersistentRecord) -> AuthorizationResult {
        return .granted
    }
    
    func canUpdate(field: String, from record: PersistentRecord) -> AuthorizationResult {
        return .granted
    }
    
    func canDelete(_ record: PersistentRecord) -> AuthorizationResult {
        return .granted
    }
}

struct AuthorizationForUser: Authorization {
    let id: String
    
    init(id: String) {
        self.id = id
    }
    
    func canCreate(_ type: String) -> AuthorizationResult {
        return .denied(reason: "not admin account")
    }
    
    func canRead(field: String, from record: PersistentRecord) -> AuthorizationResult {
        if (isMe(record)) {
            return .granted
        }
        return .denied(reason: "non-admin user can only access own record")
    }
    
    func canUpdate(field: String, from record: PersistentRecord) -> AuthorizationResult {
        if (isMe(record)) {
            return .granted
        }
        return .denied(reason: "non-admin user can only update own record")
    }
    
    func canDelete(_ record: PersistentRecord) -> AuthorizationResult {
        return .denied(reason: "not admin account")
    }
    
    func isMe(_ record: PersistentRecord) -> Bool {
        guard let user = record as? ManagedUser else {
            return false
        }
        return id == user.uuid
    }
}
