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
import NotificationService
import DataProvider

/**
 Router logic for the LDAP Gateway API in v1 (used by the Perl gateway).
 */
class LDAPGatewayAPIv1 {
    static func baseDN() -> String {
        return "dc=easylogin,dc=proxy"
    }
    
    let dataProvider: DataProvider
    
    enum CustomRequestKeys : String {
        case availableRecords
        case searchRequest
    }
    
    // MARK: Class management
    
    init() throws {
        dataProvider = try DataProvider.singleton()
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
                dataProvider.completeManagedObjects(ofType: ManagedUser.self, completion: { (managedUsers, error) in
                    guard let managedUsers = managedUsers else {
                        response.status(.internalServerError)
                        next()
                        return
                    }
                    
                    let userRecords = managedUsers.map({ (managedUser) -> LDAPUserRecord in
                        return LDAPUserRecord(managedUser: managedUser)
                    })
                    
                    request.userInfo[CustomRequestKeys.availableRecords.rawValue] = userRecords
                    next()
                    return
                })
                
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
                        
                        dataProvider.managedObject(ofType: ManagedUser.self, withUUID: recordUUID, completion: { (managedUser, error) in
                            guard let managedUser = managedUser else {
                                response.status(.notFound)
                                next()
                                return
                            }
                            
                            request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPUserRecord(managedUser: managedUser)]
                            next()
                            return
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
        if let simplePassword = authenticationChallenges.simple {
            dataProvider.completeManagedUser(withLogin: username) { (managedUser, error) in
                guard let managedUser = managedUser else {
                    completion(LDAPAuthResponse(isAuthenticated: false, message: "Authentication denied"), RequestError.unauthorized)
                    return
                }
                
                do {
                    if (try managedUser.verify(clearTextPassword: simplePassword))  {
                        completion(LDAPAuthResponse(isAuthenticated: true, message: nil), RequestError.ok)
                    }
                    else {
                        completion(LDAPAuthResponse(isAuthenticated: false, message: "Authentication denied"), RequestError.unauthorized)
                    }
                } catch {
                    completion(LDAPAuthResponse(isAuthenticated: false, message: "Authentication denied"), RequestError.unauthorized)
                }
            }
        } else {
            completion(LDAPAuthResponse(isAuthenticated: false, message: "Unsupported authentication methods"), RequestError.unauthorized)
        }
    }
    
}
