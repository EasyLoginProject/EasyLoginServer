//
//  ObjectTypeForLDAPBridgeV1.swift
//  EasyLoginPackageDescription
//
//  Created by Yoann Gini on 29/12/2017.
//

import Foundation
import Extensions
import SwiftyJSON

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
    
    let present: String?
    
    enum RepresentedFilterNode {
        case equalityMatch
        case substrings
        case and
        case or
        case not
        case present
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
            
        } else if let _ = present {
            return .present
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
    
    let scope: Int?
    
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
    
    var dn: String?
    var objectClass: [String]?
    
    var hasSubordinates: String?
    
    static func ==(lhs: LDAPRecord, rhs: LDAPRecord) -> Bool {
        return lhs.entryUUID == rhs.entryUUID
    }
    
    enum Key: String {
        case type
        case entryUUID = "_id"
        case uidNumber = "numericID"
        case uid = "shortname"
        case userPrincipalName = "principalName"
        case mail = "email"
        case givenName
        case sn = "surname"
        case cn = "fullName"
    }    
    
    init(databaseRecordForUser:JSON) throws {
        // No type or unexpected type: requested document was not found
        guard let documentType: String = databaseRecordForUser.optionalElement(.type) else { throw EasyLoginError.notFound }
        guard documentType == "user" else { throw EasyLoginError.notFound }
        // TODO: verify not deleted

        self.entryUUID = try databaseRecordForUser.mandatoryElement(.entryUUID)

        guard let uidNumber = databaseRecordForUser[Key.uidNumber.rawValue].int else { throw EasyLoginError.invalidDocument(Key.uidNumber.rawValue) }
        self.uidNumber = uidNumber
        self.uid = try databaseRecordForUser.mandatoryElement(.uid)
        self.userPrincipalName = try databaseRecordForUser.mandatoryElement(.userPrincipalName)
        self.mail = try databaseRecordForUser.mandatoryElement(.mail)
        self.cn = try databaseRecordForUser.mandatoryElement(.cn)
        self.givenName = databaseRecordForUser.optionalElement(.givenName)
        self.sn = databaseRecordForUser.optionalElement(.sn)
        
        self.dn = "entryUUID=\(self.entryUUID),cn=users,dc=easylogin,dc=proxy"
        
        self.hasSubordinates = "FALSE"
        self.objectClass = ["inetOrgPerson", "posixAccount"]
    }

}

struct LDAPRootDSE: Codable {
    let namingContexts: [String]?
    let subschemaSubentry: [String]?
    let supportedLDAPVersion: [String]?
    let supportedSASLMechanisms: [String]?
    let supportedExtension: [String]?
    let supportedControl: [String]?
    let supportedFeatures: [String]?
    let vendorName: [String]?
    let vendorVersion: [String]?
    let objectClass: [String]?
}

struct LDAPContainer: Codable {
    let entryUUID: String
    let dn: String
    let objectClass: [String]?
    let cn: String?
}

struct LDAPDomain: Codable {
    let entryUUID: String
    let dn: String
    let objectClass: [String]?
    let domain: String?
}

fileprivate extension JSON {
    func mandatoryElement<T>(_ key: LDAPRecord.Key) throws -> T {
        guard let element = self[key.rawValue].object as? T else { throw EasyLoginError.invalidDocument(key.rawValue) }
        return element
    }
    
    func mandatoryFieldFromRequest<T>(_ key: LDAPRecord.Key) throws -> T {
        guard let field = self[key.rawValue].object as? T else { throw EasyLoginError.missingField(key.rawValue) }
        return field
    }
    
    func optionalElement<T>(_ key: LDAPRecord.Key) -> T? {
        return self[key.rawValue].object as? T
    }
    
    func isNull(_ key: LDAPRecord.Key) -> Bool {
        return self[key.rawValue].exists() && Swift.type(of: self[key.rawValue].object) == NSNull.self
    }
}
