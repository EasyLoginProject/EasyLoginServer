//
//  LDAPGatewayAPIv1.swift
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

/**
 Router logic for the LDAP Gateway API in v1 (used by the Perl gateway).
 */
class LDAPGatewayAPIv1 {
    static func baseDN() -> String {
        return "dc=easylogin,dc=proxy"
    }
    
    let database: Database
    
    enum CustomRequestKeys : String {
        case availableRecords
        case searchRequest
    }
    
    // MARK: Class management
    
    init(database: Database) {
        self.database = database
        
        // TODO: Ask Frank to create a standard function linked to the atabase that can be used by any modules to load documents from the Resources folder
        let ldapDesignPath: String
        if let environmentVariable = getenv("RESOURCES"), let resourcePath = String(validatingUTF8: environmentVariable) {
            ldapDesignPath = "\(resourcePath)/ldapv1_design.json"
        }
        else {
            ldapDesignPath = "Resources/ldapv1_design.json"
        }
        
        guard let json = try? String(contentsOfFile: ldapDesignPath, encoding:.utf8) else {
            Log.error("cannot load file \(ldapDesignPath)")
            return
        }
        let ldapDesign = JSON.parse(string: json)
        
        database.retrieve("_design/ldapv1_design") { (oldDocument, error) in
            if let oldDocument = oldDocument, let rev = oldDocument["_rev"].string {
                database.update("_design/ldapv1_design", rev: rev, document: ldapDesign, callback: { (_, _, error) in
                    if error == nil {
                        Log.info("Design document for LDAP v1 updated")
                    }
                })
            } else {
                database.createDesign("ldapv1_design", document: ldapDesign) { (result, error) in
                    Log.info("LDAP database index creation: \(String(describing: result))")
                }
            }
        }
    }
    
    // MARK: - Handler and handler management
    func installHandlers(to router: Router) {
        router.ldapPOST("/v1/auth", handler: handleLDAPAuthentication)
        router.post("/v1/search", handler: loadRecordsForLDAPSearch, filterRecordsForLDAPSearch)
    }
    

    
    // MARK: Handler and subhandlers neededs for LDAP search of all kinds.
    func loadRecordsForLDAPSearch(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let searchRequest = try? request.read(as: LDAPSearchRequest.self) else {
            response.status(.unprocessableEntity)
            next()
            return
        }
        
        request.userInfo[CustomRequestKeys.searchRequest.rawValue] = searchRequest
        
        switch searchRequest.baseObject {
        case "":
            if searchRequest.scope == 0 {
                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPRootDSERecord.instanceRootDSE]
                next()
                return
            }
            response.status(.unauthorized)
            next()
            return
        case LDAPDomainRecord.instanceDomain.dn:
            if searchRequest.scope == 0 {
                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPDomainRecord.instanceDomain]
                next()
                return
            } else if searchRequest.scope == 1 {
                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPContainerRecord.userContainer, LDAPContainerRecord.groupContainer]
                next()
                return
            }
            response.status(.unauthorized)
            next()
            return
        case LDAPContainerRecord.userContainer.dn:
            if searchRequest.scope == 0 {
                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPContainerRecord.userContainer]
                next()
                return
            } else {
                database.queryByView("all_users", ofDesign: "ldapv1_design", usingParameters: []) { (databaseResponse, error) in
                    guard let databaseResponse = databaseResponse else {
                        response.status(.internalServerError)
                        next()
                        return
                    }
                    
                    let jsonDecoder = JSONDecoder()
                    
                    let userRecords = databaseResponse["rows"].array?.flatMap { user -> LDAPUserRecord? in
                        guard let record = try? jsonDecoder.decode(LDAPUserRecord.self, from:user["value"].rawData()) else {
                            return nil
                        }
                        return record
                    }
                    
                    if let userRecords = userRecords {
                        request.userInfo[CustomRequestKeys.availableRecords.rawValue] = userRecords
                        next()
                        return
                    } else {
                        response.status(.internalServerError)
                        next()
                        return
                    }
                }
                return
            }
        case LDAPContainerRecord.groupContainer.dn:
            if searchRequest.scope == 0 {
                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPContainerRecord.groupContainer]
                next()
                return
            } else {
                // Search fo groups
                response.status(.notImplemented)
                next()
                return
            }
        default:
            // Find specific record
            if let rangeOfUserDN = searchRequest.baseObject.range(of: ",\(LDAPContainerRecord.userContainer.dn)") {
                let recordInfo = searchRequest.baseObject.prefix(upTo: rangeOfUserDN.lowerBound).split(separator: "=")
                if (recordInfo.count == 2) {
                    let recordField = String(recordInfo[0])
                    let recordUUID = String(recordInfo[1])
                    if (recordField == LDAPUserRecord.fieldUsedInDN.rawValue) {
                        database.retrieve(recordUUID, callback: { (document: JSON?, error: NSError?) in
                            guard let document = document else {
                                response.status(.notFound)
                                next()
                                return
                            }
                            
                            let jsonDecoder = JSONDecoder()
                            jsonDecoder.userInfo[CodingUserInfoKey.decodingStrategy] = DecodingStrategyForRecord.decodeFromDatabaseNativeFields
                            if let record = try? jsonDecoder.decode(LDAPUserRecord.self, from: document.rawData()) {
                                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [record]
                                next()
                                return
                            } else {
                                response.status(.internalServerError)
                                next()
                                return
                            }
                        })
                        return
                    } else {
                        // Could be improved to support search by alternate field, some LDAP server support this.
                        response.status(.notImplemented)
                        next()
                        return
                    }
                } else {
                    
                }
            } else {
                response.status(.unauthorized)
                next()
                return
            }
            
            response.status(.notImplemented)
            next()
            return
        }
    }
    
    func filterRecordsForLDAPSearch(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let searchRequest = request.userInfo[CustomRequestKeys.searchRequest.rawValue] as? LDAPSearchRequest, let availableRecords = request.userInfo[CustomRequestKeys.availableRecords.rawValue] as? [LDAPAbstractRecord] else {
            if response.statusCode == .unknown {
                response.status(.internalServerError)
            }
            next()
            return
        }
        
        if let ldapFilter = searchRequest.filter {
            if let filteredRecords = ldapFilter.filter(records: availableRecords) {
                if let jsonData = try? JSONEncoder().encode(filteredRecords) {
                    response.send(data: jsonData)
                    response.status(.OK)
                    next()
                    return
                } else {
                    response.status(.internalServerError)
                    next()
                    return
                }
            } else {
                response.status(.internalServerError)
                next()
                return
            }
        } else {
            if let jsonData = try? JSONEncoder().encode(availableRecords) {
                response.send(data: jsonData)
                response.status(.OK)
                next()
                return
            } else {
                response.status(.internalServerError)
                next()
                return
            }
        }
    }
    
    // MARK: LDAP Bind management (authentication)
    
    func handleLDAPAuthentication(authRequest: LDAPAuthRequest, completion:@escaping (LDAPAuthResponse?, RequestError?) -> Void) -> Void {
        guard let username = authRequest.name else {
            completion(LDAPAuthResponse(isAuthenticated: false, message: "Username not provided"), RequestError.unauthorized)
            return
        }
        
        guard let authenticationChallenges = authRequest.authentication else {
            completion(LDAPAuthResponse(isAuthenticated: false, message: "Auhentication request missing"), RequestError.unauthorized)
            return
        }
        
        //TODO: Ask frank to provide a simplest API on ManagedUser
        database.userAuthMethods(login: username) {
            authMethods in
            guard
                let authMethods = authMethods,
                let modularString = authMethods.authMethods["pbkdf2"]
                else {
                    completion(LDAPAuthResponse(isAuthenticated: false, message: "Authentication denied"), RequestError.unauthorized)
                    return
            }
            
            if let simplePassword = authenticationChallenges.simple {
                let valid = PBKDF2.verifyPassword(simplePassword, withString: modularString)
                
                if (valid) {
                    completion(LDAPAuthResponse(isAuthenticated: true, message: nil), RequestError.ok)
                }
                else {
                    completion(LDAPAuthResponse(isAuthenticated: false, message: "Authentication denied"), RequestError.unauthorized)
                }
            } else {
                completion(LDAPAuthResponse(isAuthenticated: false, message: "Unsupported authentication methods"), RequestError.unauthorized)
            }
        }
    }
  
}
