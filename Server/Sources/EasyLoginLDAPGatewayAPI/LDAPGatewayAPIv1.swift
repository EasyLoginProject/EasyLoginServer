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
    
    enum LDAPGatewayError : Error {
        case dnFieldNotSupported
        case invalidDNSyntax
        case usernameNotSupported
    }
    
    // MARK: Class management
    
    init(dataProvider: DataProvider) {
        self.dataProvider = dataProvider
    }
    
    // MARK: - Handler and handler management
    func installHandlers(to router: Router) {
        Log.entry("Loading LDAP APIv1 router")
        router.post("/v1/auth", handler: handleLDAPAuthentication)
        router.post("/v1/search", handler: loadRecordsForLDAPSearch, filterRecordsForLDAPSearch)
        Log.exit("Loading LDAP APIv1 router")
    }
    

    
    // MARK: Handler and subhandlers needed for LDAP search of all kinds.
    func loadRecordsForLDAPSearch(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        Log.entry("Loading records for LDAP an search")
        defer {
            Log.exit("Loading records for LDAP an search")
        }
        
        guard let contentType = request.headers["Content-Type"] else {
            Log.error("Missing Content-Type")
            response.status(.unsupportedMediaType)
            next()
            return
        }
        guard contentType.hasPrefix("application/json") else {
            Log.error("Unsupported Content-Type")
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard let searchRequest = try? request.read(as: LDAPSearchRequest.self) else {
            Log.error("Unable to decode LDAP search request")
            response.status(.unprocessableEntity)
            next()
            return
        }
        
        request.userInfo[CustomRequestKeys.searchRequest.rawValue] = searchRequest
        
        switch searchRequest.baseObject {
        case "":
            if searchRequest.scope == 0 {
                Log.verbose("Looking for instance Root DSE")
                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPRootDSERecord.instanceRootDSE]
                next()
                return
            }
            Log.error("Directory transversal request for empty base object is forbidden")
            response.status(.unauthorized)
            next()
            return
        case LDAPDomainRecord.instanceDomain.dn:
            if searchRequest.scope == 0 {
                Log.verbose("Looking for domain instance info")
                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPDomainRecord.instanceDomain]
                next()
                return
            } else if searchRequest.scope == 1 {
                Log.verbose("Looking for containers under domain instance")
                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPContainerRecord.userContainer, LDAPContainerRecord.groupContainer]
                next()
                return
            }
            Log.error("Directory transversal request from domain instance is forbidden")
            response.status(.unauthorized)
            next()
            return
        case LDAPContainerRecord.userContainer.dn:
            if searchRequest.scope == 0 {
                Log.info("Looking for user contrainer info")
                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPContainerRecord.userContainer]
                next()
                return
            } else {
                Log.info("Looking for users")
                dataProvider.completeManagedObjects(ofType: ManagedUser.self, completion: { (managedUsers, error) in
                    guard let managedUsers = managedUsers else {
                        Log.error("No users found")
                        response.status(.internalServerError)
                        next()
                        return
                    }
                    
                    Log.verbose("Translating managed users into ldap users")
                    let userRecords = managedUsers.map({ (managedUser) -> LDAPUserRecord in
                        return LDAPUserRecord(managedUser: managedUser)
                    })
                    
                    Log.verbose("Translation done, forwarding result to filter function")
                    request.userInfo[CustomRequestKeys.availableRecords.rawValue] = userRecords
                    next()
                    return
                })
                
                return
            }
        case LDAPContainerRecord.groupContainer.dn:
            if searchRequest.scope == 0 {
                Log.info("Looking for group container info")
                request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPContainerRecord.groupContainer]
                next()
                return
            } else {
                Log.info("Looking for groups")
                dataProvider.completeManagedObjects(ofType: ManagedUserGroup.self, completion: { (managedUserGroups, error) in
                    guard let managedUserGroups = managedUserGroups else {
                        Log.error("No groups found")
                        response.status(.internalServerError)
                        next()
                        return
                    }
                    
                    Log.verbose("Translating managed groups info ldap groups")
                    let groupsRecords = managedUserGroups.map({ (managedUserGroup) -> LDAPUserGroupRecord in
                        return LDAPUserGroupRecord(managedUserGroup: managedUserGroup)
                    })
                    
                    Log.verbose("Translation done, forwarding result to filter function")
                    request.userInfo[CustomRequestKeys.availableRecords.rawValue] = groupsRecords
                    next()
                    return
                })
                return
            }
        default:
            // Find specific record
            if searchRequest.baseObject.hasSuffix(LDAPContainerRecord.userContainer.dn) {
                Log.info("Looking for specifc user record")
                managedUserWith(usernameOrDN:searchRequest.baseObject) { (managedUser, error) in
                    guard let managedUser = managedUser else {
                        Log.error("No user record found")
                        response.status(.notFound)
                        next()
                        return
                    }
                    
                    Log.info("User record found, tralsating and forwarding")
                    request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPUserRecord(managedUser: managedUser)]
                    next()
                    return
                }
            } else if searchRequest.baseObject.hasSuffix(LDAPContainerRecord.groupContainer.dn) {
                Log.info("Looking for specifc group record")
                managedUserGroupWith(recordIDOrDN: searchRequest.baseObject) { (managedUserGroup, error) in
                    guard let managedUserGroup = managedUserGroup else {
                        Log.error("No group record found")
                        response.status(.notFound)
                        next()
                        return
                    }
                    
                    Log.info("Group record found, tralsating and forwarding")
                    request.userInfo[CustomRequestKeys.availableRecords.rawValue] = [LDAPUserGroupRecord(managedUserGroup: managedUserGroup)]
                    next()
                    return
                }
            } else {
                Log.error("Unsupported request")
                response.status(.unauthorized)
                next()
                return
            }
        }
    }
    
    func filterRecordsForLDAPSearch(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        Log.entry("Filtering LDAP result")
        defer {
            Log.exit("Filtering LDAP result")
        }
        
        guard let searchRequest = request.userInfo[CustomRequestKeys.searchRequest.rawValue] as? LDAPSearchRequest, let availableRecords = request.userInfo[CustomRequestKeys.availableRecords.rawValue] as? [LDAPAbstractRecord] else {
            Log.error("Error processing LDAP lookup and filter")
            if response.statusCode == .unknown {
                response.status(.internalServerError)
            }
            next()
            return
        }
        
        if let ldapFilter = searchRequest.filter {
            Log.info("Applying LDAP filter on \(availableRecords.count) record(s)")
            if let filteredRecords = ldapFilter.filter(records: availableRecords) {
                if let jsonData = try? JSONEncoder().encode(filteredRecords) {
                    response.headers.setType("json")
                    response.send(data: jsonData)
                    response.status(.OK)
                    next()
                    return
                } else {
                    Log.error("Unable to encode filtered records")
                    response.status(.internalServerError)
                    next()
                    return
                }
            } else {
                Log.error("Unable to execute LDAP filter")
                response.status(.internalServerError)
                next()
                return
            }
        } else {
            Log.info("No LDAP filter requested, returing all records")
            if let jsonData = try? JSONEncoder().encode(availableRecords) {
                response.headers.setType("json")
                response.send(data: jsonData)
                response.status(.OK)
                next()
                return
            } else {
                Log.error("Unable to encode records")
                response.status(.internalServerError)
                next()
                return
            }
        }
    }
    
    // MARK: LDAP Bind management (authentication)
    
    func handleLDAPAuthentication(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let contentType = request.headers["Content-Type"] else {
            Log.error("Missing Content-Type")
            response.status(.unsupportedMediaType)
            next()
            return
        }
        guard contentType.hasPrefix("application/json") else {
            Log.error("Unsupported Content-Type")
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard let authRequest = try? request.read(as: LDAPAuthRequest.self) else {
            Log.error("Unable to decode authentication request")
            response.status(.unprocessableEntity)
            next()
            return
        }
        
        guard let username = authRequest.name else {
            Log.error("No username provied")
            response.status(.unauthorized)
            next()
            return
        }
        
        guard let authenticationChallenges = authRequest.authentication else {
            Log.error("Missing authentication challgenge")
            response.status(.unauthorized)
            next()
            return
        }
        
        if let simplePassword = authenticationChallenges.simple {
            Log.info("Authenticating using simple mechanism")
            managedUserWith(usernameOrDN: username) { (managedUser, error) in
                guard let managedUser = managedUser else {
                    Log.error("User not found")
                    response.status(.unauthorized)
                    next()
                    return
                }
                
                do {
                    Log.info("Checking credentials")
                    if (try managedUser.verify(clearTextPassword: simplePassword))  {
                        Log.info("Credentials valids")
                        response.status(.OK)
                        next()
                    }
                    else {
                        Log.error("Invalid credentials")
                        response.status(.unauthorized)
                        next()
                    }
                } catch {
                    Log.error("Unable to verify credentials")
                    response.status(.unauthorized)
                    next()
                }
            }
        } else {
            Log.error("Unsupported authentication challenge")
            response.status(.unauthorized)
            next()
        }
    }
    
    private func managedUserWith(usernameOrDN:String, completion: @escaping (ManagedUser?, CombinedError?)->Void) {
        Log.entry("Looking for user by shortname, UPN or DN")
        defer {
            Log.exit("Looking for user by shortname, UPN or DN")
        }
        // Find specific record
        if let rangeOfUserDN = usernameOrDN.range(of: ",\(LDAPContainerRecord.userContainer.dn)") {
            Log.info("Looking for a user by DN")
            let recordInfo = usernameOrDN.prefix(upTo: rangeOfUserDN.lowerBound).split(separator: "=")
            if (recordInfo.count == 2) {
                let recordField = String(recordInfo[0])
                let recordUUID = String(recordInfo[1])
                if (recordField == LDAPUserRecord.fieldUsedInDN.rawValue) {
                    Log.info("Looking for user and directly forwarding results")
                    dataProvider.completeManagedObject(ofType: ManagedUser.self, withUUID: recordUUID, completion: { (managedUser, error) in
                        completion(managedUser, error)
                    })
                } else {
                    // Could be improved to support search by alternate field, some LDAP servers support this.
                    Log.error("Unsupported field in DN")
                    completion(nil, .swiftError(LDAPGatewayError.dnFieldNotSupported))
                }
            } else {
                Log.error("Invalid DN syntax")
                completion(nil, .swiftError(LDAPGatewayError.invalidDNSyntax))
            }
        } else {
            Log.info("Looking for user by shortname or UPN and directly forwarding results")
            dataProvider.completeManagedUser(withLogin: usernameOrDN) { (managedUser, error) in
                completion(managedUser, error)
            }
        }
    }
    
    private func managedUserGroupWith(recordIDOrDN:String, completion: @escaping (ManagedUserGroup?, CombinedError?)->Void) {
        Log.entry("Looking for group by shortname or DN")
        defer {
            Log.exit("Looking for group by shortname or DN")
        }
        // Find specific record
        if let rangeOfUserDN = recordIDOrDN.range(of: ",\(LDAPContainerRecord.groupContainer.dn)") {
            Log.info("Looking for a group by DN")
            let recordInfo = recordIDOrDN.prefix(upTo: rangeOfUserDN.lowerBound).split(separator: "=")
            if (recordInfo.count == 2) {
                let recordField = String(recordInfo[0])
                let recordUUID = String(recordInfo[1])
                if (recordField == LDAPUserGroupRecord.fieldUsedInDN.rawValue) {
                    Log.info("Looking for user and directly forwarding results")
                    dataProvider.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordUUID, completion: { (managedUserGroup, error) in
                        completion(managedUserGroup, error)
                    })
                } else {
                    // Could be improved to support search by alternate field, some LDAP servers support this.
                    Log.error("Unsupported field in DN")
                    completion(nil, .swiftError(LDAPGatewayError.dnFieldNotSupported))
                }
            } else {
                Log.error("Invalid DN syntax")
                completion(nil, .swiftError(LDAPGatewayError.invalidDNSyntax))
            }
        } else {
            Log.info("Looking for group by shortname and directly forwarding results")
            dataProvider.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordIDOrDN) { (managedUserGroup, error) in
                completion(managedUserGroup, error)
            }
        }
    }
}
