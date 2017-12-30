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
    }
    
    func handleLDAPSearch(searchRequest: LDAPSearchRequest, completion:@escaping ([LDAPRecord]?, RequestError?) -> Void) -> Void {
        guard let ldapFilter = searchRequest.filter else {
            completion(nil, RequestError.unprocessableEntity)
            return
        }
       
        guard let collectionName = recordTypeFromSearchBase(searchRequest.baseObject) else {
            completion(nil, RequestError.unauthorized)
            return
        }
        
        let databaseViewForSearch: String
        if collectionName == "users" {
            databaseViewForSearch = "all_users"
        } else if collectionName == "general_server_info" {
            
            return
        } else {
            completion(nil, RequestError.unauthorized)
            return
        }
       
        database.queryByView(databaseViewForSearch, ofDesign: "ldapv1_design", usingParameters: []) { (databaseResponse, error) in
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
                let testedValue: String?
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
                default:
                    testedValue = nil
                }
                
                if let testedValue = testedValue {
                    return testedValue == equalityMatch.assertionValue
                } else {
                    return false
                }
            })
        }
            // Substrings Operation
        else if let substringsFilter = ldapFilter.substrings {
            
            return ldapRecords.filter({ (recordToCheck) -> Bool in
                var valueToEvaluate: String?
                var valuesToEvaluate: [String]?
                let isMultivalued: Bool
                switch substringsFilter.type {
                case "entryUUID":
                    valueToEvaluate = recordToCheck.entryUUID
                    isMultivalued = false
                case "uid":
                    valueToEvaluate = recordToCheck.uid
                    isMultivalued = false
                case "userPrincipalName":
                    valueToEvaluate = recordToCheck.userPrincipalName
                    isMultivalued = false
                case "mail":
                    valueToEvaluate = recordToCheck.mail
                    isMultivalued = false
                case "givenName":
                    valueToEvaluate = recordToCheck.givenName
                    isMultivalued = false
                case "sn":
                    valueToEvaluate = recordToCheck.sn
                    isMultivalued = false
                case "cn":
                    valueToEvaluate = recordToCheck.cn
                    isMultivalued = false
                case "dn":
                    valueToEvaluate = recordToCheck.dn
                    isMultivalued = false
                case "objectClass":
                    valuesToEvaluate = recordToCheck.objectClass
                    isMultivalued = true
                default:
                    valueToEvaluate = nil
                    isMultivalued = false
                }
                
                if !isMultivalued {
                    if let valueToEvaluate = valueToEvaluate {
                        valuesToEvaluate = [valueToEvaluate]
                    }
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
                case "objectClass":
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
  
    func recordTypeFromSearchBase(_ ldapSearchBase: String) -> String? {
        if ldapSearchBase.hasSuffix(",dc=easylogin,dc=proxy") {
            let requestedTree = ldapSearchBase.replacingOccurrences(of: ",dc=easylogin,dc=proxy", with: "")
            let requestedTreeFields = requestedTree.split(separator: ",")
            
            if requestedTreeFields.count == 1 {
                let requestForType = requestedTreeFields[0]
                let requestForTypeFields = requestForType.split(separator: "=")
                
                if requestForTypeFields.count == 2 {
                    if requestForTypeFields[0] == "cn" {
                        return String(requestForTypeFields[1])
                    }
                }
            }
        } else if ldapSearchBase == "" {
            return "general_server_info"
        }
        
        return nil
    }
}
