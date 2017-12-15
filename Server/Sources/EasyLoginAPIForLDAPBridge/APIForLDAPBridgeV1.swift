//
//  APIForLDAPBridgeV1.swift
//  EasyLoginServer
//
//  Created by Yoann Gini on 15/12/2017.
//

import Foundation
import CouchDB
import Kitura
import KituraContracts
import LoggerAPI
import SwiftyJSON
import Extensions
import NotificationService

struct LDAPAuthRequest: Codable {
    struct LDAPAuthScheme: Codable {
        let simple: String?
    }
    
    let authentication: LDAPAuthScheme?
    let name: String?
    let version: Int?
}

struct LDAPAuthResponse: Codable {
    let isAuthenticated: Bool
    let message: String?
}

class APIForLDAPBridgeV1 {
    let database: Database
    
    init(database: Database) {
        self.database = database
    }
    
    func installHandlers(to router: Router) {
        router.post("/v1/auth", handler: handleLDAPAuthentication)
    }

    func handleLDAPAuthentication(authRequest: LDAPAuthRequest, completion:@escaping (LDAPAuthResponse?, RequestError?) -> Void) -> Void {
        
        guard let username = authRequest.name else {
            completion(LDAPAuthResponse(isAuthenticated: false, message: "Username not provided"), RequestError.unauthorized)
            return
        }
        
        guard let offeredAuthenticationMethods = authRequest.authentication, let simplePassword = offeredAuthenticationMethods.simple else {
            completion(LDAPAuthResponse(isAuthenticated: false, message: "Unsupported authentication method"), RequestError.unauthorized)
            return
        }
        
        database.userAuthMethods(login: username) {
            authMethods in
            guard
                let authMethods = authMethods,
                let modularString = authMethods.authMethods["pbkdf2"]
                else {
                    completion(LDAPAuthResponse(isAuthenticated: false, message: "Authentication denied"), RequestError.unauthorized)
                    return
            }
            
            let valid = PBKDF2.verifyPassword(simplePassword, withString: modularString)
            
            if (valid) {
                completion(LDAPAuthResponse(isAuthenticated: true, message: nil), RequestError.ok)
            }
            else {
                completion(LDAPAuthResponse(isAuthenticated: false, message: "Authentication denied"), RequestError.unauthorized)
            }
        }
        
        completion(LDAPAuthResponse(isAuthenticated: false, message: "Unkown failure"), RequestError.unauthorized)
    }
}
