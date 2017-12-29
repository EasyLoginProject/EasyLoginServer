//
//  ObjectTypeForLDAPBridgeV1.swift
//  EasyLoginPackageDescription
//
//  Created by Yoann Gini on 29/12/2017.
//

import Foundation
import Extensions

// MARK: - Codable objects for LDAP authentication requests

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

// MARK: - Codable objects for LDAP search requests

class LDAPFilter: Codable {
    
    struct LDAPFilterSettingEqualityMatch: Codable {
        let attributeDesc: String
        let assertionValue: String
    }
    
    struct LDAPFilterSettingSubstring: Codable {
        let type: String
        let substrings: [[String:String]]
    }
    
    let equalityMatch: LDAPFilterSettingEqualityMatch?
    let substrings: LDAPFilterSettingSubstring?
    
    let and: [LDAPFilter]?
    let or: [LDAPFilter]?
    let not: LDAPFilter?
    
    enum RepresentedFilterNode {
        case equalityMatch
        case substrings
        case and
        case or
        case not
        case unkown
    }
    
    func nodeType() -> RepresentedFilterNode {
        if let _ = equalityMatch {
            return .equalityMatch
            
        } else if let _ = substrings {
            return .substrings
            
        } else if let _ = and {
            return .and
            
        } else if let _ = or {
            return .or
            
        } else if let _ = not {
            return .not
            
        }
        
        return .unkown
    }
    
    func isAnOperator() -> Bool {
        switch nodeType() {
        case .and,.or:
            return true
        default:
            return false
        }
    }
    
    func nestedFilters() -> [LDAPFilter]? {
        if let and = and {
            return and
        } else if let or = or {
            return or
        } else {
            return nil
        }
    }
    
    func isANegation() -> Bool {
        if nodeType() == .not {
            return true
        } else {
            return false
        }
    }
}

struct LDAPSearchRequest: Codable {
    
    let filter: LDAPFilter?
    let baseObject: String
    
    let attributes: [String]?
}

struct LDAPRecord: Codable, Equatable {
    let entryUUID: String
    let uidNumber: Int?
    let uid: String?
    let userPrincipalName: String?
    let mail: String?
    let givenName: String?
    let sn: String?
    let cn: String?
    
    static func ==(lhs: LDAPRecord, rhs: LDAPRecord) -> Bool {
        return lhs.entryUUID == rhs.entryUUID
    }
}

