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

// MARK: - LDAP REST Backend, Class V1

class APIForLDAPBridgeV1 {
    let database: Database
    
    let rootDSE = LDAPRootDSE(namingContexts: ["dc=easylogin,dc=proxy"],
                              subschemaSubentry: ["cn=schema"],
                              supportedLDAPVersion: ["3"],
                              supportedSASLMechanisms: [],
                              supportedExtension: [],
                              supportedControl: [],
                              supportedFeatures: [],
                              vendorName: ["EasyLogin"],
                              vendorVersion: ["1"],
                              objectClass: ["top"])

    let baseContainer = LDAPDomain(entryUUID: "00000000-0000-0000-0000-000000000000",
                                   dn: "dc=easylogin,dc=proxy",
                                   objectClass: ["top", "domain"],
                                   domain: "easylogin")
    
    let userContainer = LDAPContainer(entryUUID: "00000000-0000-0000-0000-000000000001",
                                      dn: "cn=users,dc=easylogin,dc=proxy",
                                      objectClass: ["top", "container"],
                                      cn: "users")
    
    let groupContainer = LDAPContainer(entryUUID: "00000000-0000-0000-0000-000000000002",
                                       dn: "cn=groups,dc=easylogin,dc=proxy",
                                       objectClass: ["top", "container"],
                                       cn: "groups")
    
    init(database: Database) {
        self.database = database
        
        
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
    
    // MARK: Handler and handler management
    func installHandlers(to router: Router) {
        router.ldapPOST("/v1/auth", handler: handleLDAPAuthentication)
        router.ldapPOST("/v1/search", handler: handleLDAPSearch)
        router.get("/v1/rootdse", handler: handleRootDSERequest)
        router.get("/v1/firstlevelcontainers", handler: handleFirstLevelContrainers)
        router.get("/v1/basecontainer", handler: handleBaseObjectInfo)
    }
    
    func handleBaseObjectInfo(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        if let encodedRootObjects = try? JSONEncoder().encode(baseContainer) {
            response.headers.setType("json")
            response.status(.OK)
            response.send(data: encodedRootObjects)
        } else {
            response.status(.internalServerError)
        }
        
        next()
    }
    
    func handleFirstLevelContrainers(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        
        let rootObjects = [userContainer, groupContainer]
        
        if let encodedRootObjects = try? JSONEncoder().encode(rootObjects) {
            response.headers.setType("json")
            response.status(.OK)
            response.send(data: encodedRootObjects)
        } else {
            response.status(.internalServerError)
        }
        
        next()
    }
    
    func handleRootDSERequest(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        if let encodedRootDSE = try? JSONEncoder().encode(rootDSE) {
            response.headers.setType("json")
            response.status(.OK)
            response.send(data: encodedRootDSE)
        } else {
            response.status(.internalServerError)
        }
        
        next()
    }
    
    func handleLDAPSearch(searchRequest: LDAPSearchRequest, completion:@escaping ([LDAPRecord]?, RequestError?) -> Void) -> Void {
        guard let ldapFilter = searchRequest.filter else {
            completion(nil, RequestError.unprocessableEntity)
            return
        }
        
        
        guard let (collectionName, requestedID) = recordTypeFromSearchBase(searchRequest.baseObject) else {
            completion(nil, RequestError.unauthorized)
            return
        }
        
        if collectionName == "users" {
            if let requestedID = requestedID {
                database.retrieve(requestedID, callback: { (document: JSON?, error: NSError?) in
                    guard let document = document else {
                        completion(nil, RequestError.notFound)
                        return
                    }
                    do {
                        let record = try LDAPRecord(databaseRecordForUser: document)
                        completion([record], RequestError.ok)
                    }
                    catch {
                        completion(nil, RequestError.internalServerError)
                    }
                })
            } else {
                if searchRequest.scope == 0 {
                    completion(nil, RequestError.unprocessableEntity)
                } else {
                    database.queryByView("all_users", ofDesign: "ldapv1_design", usingParameters: []) { (databaseResponse, error) in
                        guard let databaseResponse = databaseResponse else {
                            completion(nil, RequestError.internalServerError)
                            return
                        }
                        
                        let jsonDecoder = JSONDecoder()
                        
                        let ldapRecords = databaseResponse["rows"].array?.flatMap { user -> LDAPRecord? in
                            guard let rawJSON = try? user["value"].rawData() else {
                                return nil
                            }
                            
                            guard var record = try? jsonDecoder.decode(LDAPRecord.self, from:rawJSON) else {
                                return nil
                            }
                            
                            record.dn = "entryUUID=\(record.entryUUID),cn=\(collectionName),dc=easylogin,dc=proxy"
                            record.hasSubordinates = "FALSE"
                            if collectionName == "users" {
                                record.objectClass = ["inetOrgPerson", "posixAccount"]
                            }
                            
                            return record
                        }
                        
                        if let ldapRecords = ldapRecords {
                            if let result = self.perform(ldapFilter: ldapFilter, onRecords: ldapRecords) {
                                completion(result, RequestError.ok)
                            } else {
                                completion(nil, RequestError.internalServerError)
                            }
                        } else {
                            completion(nil, RequestError.internalServerError)
                        }
                    }
                }
            }
            
            completion(nil, RequestError.unsupportedMediaType)
        } else {
            completion(nil, RequestError.unauthorized)
            return
        }
        

    }
    
    func handleLDAPAuthentication(authRequest: LDAPAuthRequest, completion:@escaping (LDAPAuthResponse?, RequestError?) -> Void) -> Void {
        guard let username = authRequest.name else {
            completion(LDAPAuthResponse(isAuthenticated: false, message: "Username not provided"), RequestError.unauthorized)
            return
        }
        
        guard let authenticationChallenges = authRequest.authentication else {
            completion(LDAPAuthResponse(isAuthenticated: false, message: "Auhentication request missing"), RequestError.unauthorized)
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
    
    // MARK: Subroutines for LDAP search
    func perform(ldapFilter: LDAPFilter, onRecords ldapRecords: [LDAPRecord]) -> [LDAPRecord]? {

        // AND Operator
        if let nestedFilters = ldapFilter.and {
            var combinedResult = [LDAPRecord]()
            var firstLoop = true
            
            for nestedFilter in nestedFilters {
                if let nestedResult = perform(ldapFilter: nestedFilter, onRecords: ldapRecords) {
                    
                    if firstLoop {
                        combinedResult.append(contentsOf: nestedResult)
                        firstLoop = false
                    } else {
                        combinedResult = combinedResult.filter({ (recordFromCombinedResult) -> Bool in
                            return nestedResult.contains(recordFromCombinedResult)
                        })
                    }
                } else {
                    return nil
                }
            }
            
            return combinedResult
        }
            
            // OR Operator
        else if let nestedFilters = ldapFilter.or {
            var combinedResult = [LDAPRecord]()
            
            for nestedFilter in nestedFilters {
                if let nestedResult = perform(ldapFilter: nestedFilter, onRecords: ldapRecords) {
                    combinedResult.append(contentsOf: nestedResult)
                } else {
                    return nil
                }
            }
            
            return combinedResult
        }
            
            
            // NOT Operator
        else if let nestedFilter = ldapFilter.not {
            if let resultToSkip = perform(ldapFilter: nestedFilter, onRecords: ldapRecords) {
                return ldapRecords.filter({ (recordToEvaluate) -> Bool in
                    return !resultToSkip.contains(recordToEvaluate)
                })
            } else {
                return nil
            }
        }
            
            // Equality Match Operation
        else if let equalityMatch = ldapFilter.equalityMatch {
            return ldapRecords.filter({ (recordToCheck) -> Bool in
                var testedValue: String?
                var testedValues: [String]?
                
                switch equalityMatch.attributeDesc {
                case "entryUUID":
                    testedValue = recordToCheck.entryUUID
                case "uidNumber":
                    if let uidNumber = recordToCheck.uidNumber {
                        testedValue = String(uidNumber)
                    } else {
                        testedValue = nil
                    }
                case "uid":
                    testedValue = recordToCheck.uid
                case "userPrincipalName":
                    testedValue = recordToCheck.userPrincipalName
                case "mail":
                    testedValue = recordToCheck.mail
                case "givenName":
                    testedValue = recordToCheck.givenName
                case "sn":
                    testedValue = recordToCheck.sn
                case "cn":
                    testedValue = recordToCheck.cn
                case "objectClass", "objectCategory":
                    testedValues = recordToCheck.objectClass
                default:
                    testedValue = nil
                }
                
                if let testedValue = testedValue {
                    testedValues = [testedValue]
                }
                
                if let testedValues = testedValues {
                    for testedValue in testedValues {
                        if testedValue == equalityMatch.assertionValue {
                            return true
                        }
                    }
                }
                return false
            })
        }
            // Substrings Operation
        else if let substringsFilter = ldapFilter.substrings {
            
            return ldapRecords.filter({ (recordToCheck) -> Bool in
                var valueToEvaluate: String?
                var valuesToEvaluate: [String]?
                switch substringsFilter.type {
                case "entryUUID":
                    valueToEvaluate = recordToCheck.entryUUID
                case "uid":
                    valueToEvaluate = recordToCheck.uid
                case "userPrincipalName":
                    valueToEvaluate = recordToCheck.userPrincipalName
                case "mail":
                    valueToEvaluate = recordToCheck.mail
                case "givenName":
                    valueToEvaluate = recordToCheck.givenName
                case "sn":
                    valueToEvaluate = recordToCheck.sn
                case "cn":
                    valueToEvaluate = recordToCheck.cn
                case "dn":
                    valueToEvaluate = recordToCheck.dn
                case "objectClass", "objectCategory":
                    valuesToEvaluate = recordToCheck.objectClass
                default:
                    valueToEvaluate = nil
                }
                
                if let valueToEvaluate = valueToEvaluate {
                    valuesToEvaluate = [valueToEvaluate]
                }
                
                if let valuesToEvaluate = valuesToEvaluate {
                    for valueToEvaluate in valuesToEvaluate {
                        for substrings in substringsFilter.substrings {
                            for (matchType, value) in substrings {
                                switch matchType {
                                case "any":
                                    if valueToEvaluate.contains(value) {
                                        return true
                                    }
                                case "initial":
                                    if valueToEvaluate.hasPrefix(value) {
                                        return true
                                    }
                                case "final":
                                    if valueToEvaluate.hasSuffix(value) {
                                        return true
                                    }
                                default: break
                                }
                            }
                        }
                    }
                    return false
                }
                
                return false
            })
        } else if let mustBePresent = ldapFilter.present {
            return ldapRecords.filter({ (recordToCheck) -> Bool in
                switch mustBePresent {
                case "entryUUID":
                    return true
                case "uid":
                    if let _ = recordToCheck.uid {
                        return true
                    } else {
                        return false
                    }
                case "userPrincipalName":
                    if let _ = recordToCheck.userPrincipalName {
                        return true
                    } else {
                        return false
                    }
                case "mail":
                    if let _ = recordToCheck.mail {
                        return true
                    } else {
                        return false
                    }
                case "givenName":
                    if let _ = recordToCheck.givenName {
                        return true
                    } else {
                        return false
                    }
                case "sn":
                    if let _ = recordToCheck.sn {
                        return true
                    } else {
                        return false
                    }
                case "cn":
                    if let _ = recordToCheck.cn {
                        return true
                    } else {
                        return false
                    }
                case "dn":
                    if let _ = recordToCheck.dn {
                        return true
                    } else {
                        return false
                    }
                case "objectClass", "objectCategory":
                    if let objectClasses = recordToCheck.objectClass {
                        return objectClasses.count > 0
                    } else {
                        return false
                    }
                default:
                    return false
                }
            })
        }
            
            // Unkown operator or operation
        return nil
    }
  
    func recordTypeFromSearchBase(_ ldapSearchBase: String) -> (String,String?)? {
        if ldapSearchBase.hasSuffix(",dc=easylogin,dc=proxy") {
            let requestedTree = ldapSearchBase.replacingOccurrences(of: ",dc=easylogin,dc=proxy", with: "")
            let requestedTreeFields = requestedTree.split(separator: ",")
            
            if requestedTreeFields.count == 1 {
                let requestForType = requestedTreeFields[0]
                let requestForTypeFields = requestForType.split(separator: "=")
                
                if requestForTypeFields.count == 2 {
                    if requestForTypeFields[0] == "cn" {
                        return (String(requestForTypeFields[1]), nil)
                    }
                }
            } else if requestedTreeFields.count == 2 {
                let requestForTypeFieldsForLeaf = requestedTreeFields[0].split(separator: "=")
                let requestForTypeFieldsForNode = requestedTreeFields[1].split(separator: "=")
                
                if requestForTypeFieldsForLeaf.count == 2 {
                    if requestForTypeFieldsForLeaf[0] == "entryUUID" {
                        if requestForTypeFieldsForNode.count == 2 {
                            if requestForTypeFieldsForNode[0] == "cn" {
                                return (String(requestForTypeFieldsForNode[1]), String(requestForTypeFieldsForLeaf[1]))
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
}
