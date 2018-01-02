//
//  LDAPGatewayAPIv1DataTypes.swift
//  EasyLoginPackageDescription
//
//  Created by Yoann Gini on 29/12/2017.
//

import Foundation
import DataProvider

// MARK: - Codable objects for LDAP authentication requests

/**
 Represent an LDAP authentication request once converted to LDAP by the Perl gateway.
 Support only simple authentication at this time.
 */
struct LDAPAuthRequest: Codable {
    struct LDAPAuthScheme: Codable {
        let simple: String?
    }
    
    let authentication: LDAPAuthScheme?
    let name: String?
    let version: Int?
}

/**
 Represent all kind of complex filter request provided by the Perl gateway.
 Filter can be nested and agregated via an operator (and, or, not),
 so LDAPFilter need to be a class that can reference other instances.
 
 LDAPFilter aren't provided directly by the LDAP gateway, it come via a LDAPSearchRequest
 that provide context information for the lookup.
 */
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
    
    /**
     Return an enum based value representing the filter type.
     All operation having different use case based on the filter type must use this value
     and must avoid directly testing the properties' existence.
     
     Using the enum will allow compiler to warn us to update all dependent code if we add a filter type.
     
     - returns: a value of RepresentedFilterNode type
     */
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
    
    /**
     Recursive method that will filter provided records based on the complete filter tree represented by this object.
     
     - parameter records: an array of record to filter
     - returns: a new array representing all records who passed all the tests.
     */
    func filter(records: [LDAPAbstractRecord]) -> [LDAPAbstractRecord]? {
        switch nodeType() {
        case .and:
            if let nestedFilters = and {
                var combinedResult = [LDAPAbstractRecord]()
                var firstLoop = true
                for nestedFilter in nestedFilters {
                    if let nestedResult = nestedFilter.filter(records: records) {
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
            
        case .or:
            if let nestedFilters = or {
                var combinedResult = [LDAPAbstractRecord]()
                
                for nestedFilter in nestedFilters {
                    if let nestedResult = nestedFilter.filter(records: records) {
                        combinedResult.append(contentsOf: nestedResult)
                    } else {
                        return nil
                    }
                }
                
                return combinedResult
            }
            
        case .not:
            if let nestedFilter = not {
                if let resultToSkip = nestedFilter.filter(records: records) {
                    return records.filter({ (recordToEvaluate) -> Bool in
                        return !resultToSkip.contains(recordToEvaluate)
                    })
                } else {
                    return nil
                }
            }
            
        case .equalityMatch:
            if let equalityMatch = equalityMatch {
                return records.filter({ (recordToCheck) -> Bool in
                    if let testedValues = recordToCheck.valuesForField(equalityMatch.attributeDesc) {
                        for testedValue in testedValues {
                            if testedValue == equalityMatch.assertionValue {
                                return true
                            }
                        }
                    }
                    return false
                })
            }
            
        case .substrings:
            if let substringsFilter = substrings {
                return records.filter({ (recordToCheck) -> Bool in
                    if let valuesToEvaluate = recordToCheck.valuesForField(substringsFilter.type) {
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
            }
            
        case .present:
            if let mustBePresent = present {
                return records.filter({ (recordToCheck) -> Bool in
                    if let _ = recordToCheck.valuesForField(mustBePresent){
                        return true
                    } else {
                        return false
                    }
                })
            }
            
        case .unkown:
            return nil
        }
        return nil
    }
    
}

/**
 An LDAPSearchRequest represent the root object sent via the Perl gateway when
 looking for a record.
 
 Filters needs to be applied to all objects grabbed by the combinaison of the baseObject and the scope.
 */
struct LDAPSearchRequest: Codable {
    let filter: LDAPFilter?
    let baseObject: String
    
    let scope: Int?
    
    let attributes: [String]?
}

// MARK: - LDAP Special Objects

enum LDAPFeild : String {
    case entryUUID
    case uidNumber
    case uid
    case userPrincipalName
    case mail
    case givenName
    case sn
    case cn
    case dc
}

extension CodingUserInfoKey {
    static let decodingStrategy = CodingUserInfoKey(rawValue: "decodingStrategy")!
}

/**
 Base object for all record that can be requested by the client. Provide some basics for DN construction, object comparaison, filtering process…
 */
class LDAPAbstractRecord : Codable, Equatable {
    let entryUUID: String
    
    var objectClass: [String] {
        get {
            return privateObjectClass
        }
    }
    fileprivate var privateObjectClass: [String] = []
    
    var dn: String {
        get {
            if let parentContainer = parentContainer {
                return "\(fieldUsedInDN.rawValue)=\(valueUsedInDN),\(parentContainer.dn)"
            } else {
                return "\(fieldUsedInDN.rawValue)=\(valueUsedInDN)"
            }
        }
    }
    var parentContainer: LDAPAbstractRecord? {
        get {
            return privateParentContainer
        }
    }
    fileprivate var privateParentContainer: LDAPAbstractRecord? = nil
    
    
    static func ==(lhs: LDAPAbstractRecord, rhs: LDAPAbstractRecord) -> Bool {
        return lhs.entryUUID == rhs.entryUUID
    }
    
    // MARK: Part that need to be extended by subclasses
    var hasSubordinates: String {
        get {
            return privateHasSubordinates
        }
    }
    fileprivate var privateHasSubordinates: String = "FALSE"
    
    var fieldUsedInDN: LDAPFeild {
        get {
            return .entryUUID
        }
    }
    var valueUsedInDN: String {
        get {
            return entryUUID
        }
    }
    
    enum LDAPAbstractRecordCodingKeys: String, CodingKey {
        case entryUUID
        case objectClass
        case hasSubordinates
        case dn
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: LDAPAbstractRecordCodingKeys.self)
        entryUUID = try values.decode(String.self, forKey: .entryUUID)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LDAPAbstractRecordCodingKeys.self)
        try container.encode(entryUUID, forKey: .entryUUID)
        try container.encode(objectClass, forKey: .objectClass)
        try container.encode(hasSubordinates, forKey: .hasSubordinates)
        try container.encode(dn, forKey: .dn)
    }
    
    init(entryUUID: String) {
        self.entryUUID = entryUUID
    }
    
    init(managedObject:ManagedObject) {
        entryUUID = managedObject.uuid
    }
    
    func valuesForField(_ field:String) -> [String]? {
        var key: LDAPAbstractRecordCodingKeys?
        for k in iterateEnum(LDAPAbstractRecordCodingKeys.self) {
            if k.rawValue.lowercased() == field.lowercased() {
                key = k
                break
            }
        }
        if let key = key {
            switch key {
            case .entryUUID:
                return [entryUUID]
            case .objectClass:
                return objectClass
            case .hasSubordinates:
                return [hasSubordinates]
            case .dn:
                return [dn]
            }
        } else {
            return nil
        }
    }
}

/**
 The LDAP Root DSE is a specific object with dn set to "".
 It will be used by LDAP clients to understand the global context of our LDAP realm.
 */
class LDAPRootDSERecord: LDAPAbstractRecord {
    override var dn: String {
        get {
            return "" // Special case, Root DSE is he no DN object
        }
    }
    
    let namingContexts: [String]?
    let subschemaSubentry: [String]?
    let supportedLDAPVersion: [String]?
    let supportedSASLMechanisms: [String]?
    let supportedExtension: [String]?
    let supportedControl: [String]?
    let supportedFeatures: [String]?
    let vendorName: [String]?
    let vendorVersion: [String]?
    
    
    enum LDAPRootDSERecordCodingKeys: String, CodingKey {
        case namingContexts
        case subschemaSubentry
        case supportedLDAPVersion
        case supportedSASLMechanisms
        case supportedExtension
        case supportedControl
        case supportedFeatures
        case vendorName
        case vendorVersion
    }
    
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: LDAPRootDSERecordCodingKeys.self)
        try container.encode(namingContexts, forKey: .namingContexts)
        try container.encode(subschemaSubentry, forKey: .subschemaSubentry)
        try container.encode(supportedLDAPVersion, forKey: .supportedLDAPVersion)
        try container.encode(supportedSASLMechanisms, forKey: .supportedSASLMechanisms)
        try container.encode(supportedExtension, forKey: .supportedExtension)
        try container.encode(supportedControl, forKey: .supportedControl)
        try container.encode(supportedFeatures, forKey: .supportedFeatures)
        try container.encode(vendorName, forKey: .vendorName)
        try container.encode(vendorVersion, forKey: .vendorVersion)
    }
    
    required init(from decoder: Decoder) throws {
        namingContexts = nil
        subschemaSubentry = nil
        supportedLDAPVersion = nil
        supportedSASLMechanisms = nil
        supportedExtension = nil
        supportedControl = nil
        supportedFeatures = nil
        vendorName = nil
        vendorVersion = nil
        try super.init(from: decoder)
        privateObjectClass = ["top"]
        privateHasSubordinates = "TRUE"
    }
    
    init(entryUUID: String, namingContexts: [String]?, subschemaSubentry: [String]?, supportedLDAPVersion: [String]?, supportedSASLMechanisms: [String]?, supportedExtension: [String]?, supportedControl: [String]?, supportedFeatures: [String]?, vendorName: [String]?, vendorVersion: [String]?) {
        self.namingContexts = namingContexts
        self.subschemaSubentry = subschemaSubentry
        self.supportedLDAPVersion = supportedLDAPVersion
        self.supportedSASLMechanisms = supportedSASLMechanisms
        self.supportedExtension = supportedExtension
        self.supportedControl = supportedControl
        self.supportedFeatures = supportedFeatures
        self.vendorName = vendorName
        self.vendorVersion = vendorVersion
        super.init(entryUUID: entryUUID)
        privateObjectClass = ["top"]
        privateHasSubordinates = "TRUE"
    }
    
    override func valuesForField(_ field:String) -> [String]? {
        var key: LDAPRootDSERecordCodingKeys?
        for k in iterateEnum(LDAPRootDSERecordCodingKeys.self) {
            if k.rawValue.lowercased() == field.lowercased() {
                key = k
                break
            }
        }
        if let key = key {
            switch key {
            case .namingContexts:
                return namingContexts
            case .subschemaSubentry:
                return subschemaSubentry
            case .supportedLDAPVersion:
                return supportedLDAPVersion
            case .supportedSASLMechanisms:
                return supportedSASLMechanisms
            case .supportedExtension:
                return supportedExtension
            case .supportedControl:
                return supportedControl
            case .supportedFeatures:
                return supportedFeatures
            case .vendorName:
                return vendorName
            case .vendorVersion:
                return vendorVersion
            }
        } else {
            return super.valuesForField(field)
        }
    }
    
    static let instanceRootDSE = {
        return LDAPRootDSERecord(entryUUID:"00000000-0000-0000-0000-000000000000",
                                 namingContexts: [LDAPGatewayAPIv1.baseDN()],
                                 subschemaSubentry: ["cn=schema"],
                                 supportedLDAPVersion: ["3"],
                                 supportedSASLMechanisms: [],
                                 supportedExtension: [],
                                 supportedControl: [],
                                 supportedFeatures: [],
                                 vendorName: ["EasyLogin"],
                                 vendorVersion: ["1"])
        
    }()
}

/**
 LDAP domain is the root object of our LDAP realm, dn is something like "dc=easylogin,dc=proxy".
 */
class LDAPDomainRecord: LDAPAbstractRecord {
    let dc: String
    
    
    static let fieldUsedInDN: LDAPFeild = .dc
    
    override var fieldUsedInDN: LDAPFeild {
        get {
            return .dc
        }
    }
    override var valueUsedInDN: String {
        get {
            return dc
        }
    }
    
    enum LDAPDomainRecordCodingKeys: String, CodingKey {
        case dc
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: LDAPDomainRecordCodingKeys.self)
        dc = try values.decode(String.self, forKey: .dc)
        try super.init(from: decoder)
        privateObjectClass = ["domain", "top"]
        privateHasSubordinates = "TRUE"
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: LDAPDomainRecordCodingKeys.self)
        try container.encode(dc, forKey: .dc)
    }
    
    init(entryUUID: String, dc: String) {
        self.dc = dc
        super.init(entryUUID: entryUUID)
        privateObjectClass = ["domain", "top"]
        privateHasSubordinates = "TRUE"
    }
    
    override func valuesForField(_ field:String) -> [String]? {
        var key: LDAPDomainRecordCodingKeys?
        for k in iterateEnum(LDAPDomainRecordCodingKeys.self) {
            if k.rawValue.lowercased() == field.lowercased() {
                key = k
                break
            }
        }
        if let key = key {
            switch key {
            case .dc:
                return [dc]
            }
        } else {
            return super.valuesForField(field)
        }
    }
    
    static let instanceDomain: LDAPDomainRecord = {
        var fieldsOfInstanceDomain = [LDAPDomainRecord]()
        var index = 0
        var lastDomain: LDAPDomainRecord? = nil
        for domainDescription in LDAPGatewayAPIv1.baseDN().split(separator: ",").reversed() {
            let domainInfo = domainDescription.split(separator: "=")
            let previousDomain = lastDomain
            lastDomain = LDAPDomainRecord(entryUUID: String(format: "10000000-0000-0000-0000-%012d", index), dc: String(domainInfo[1]))
            if let previousDomain = previousDomain {
                lastDomain?.privateParentContainer = previousDomain
            }
            index += 1
        }
        return lastDomain!
    }()
}

/**
 An LDAP container is a node object in the tree (when records are the leaf).
 Containers has basic class and dn plus a common name. This is usually used
 to split groups and users.
 */
class LDAPContainerRecord: LDAPAbstractRecord {
    let cn: String
    
    
    static let fieldUsedInDN: LDAPFeild = .cn
    
    override var fieldUsedInDN: LDAPFeild {
        get {
            return .cn
        }
    }
    override var valueUsedInDN: String {
        get {
            return cn
        }
    }
    
    enum LDAPContainerRecordCodingKeys: String, CodingKey {
        case cn
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: LDAPContainerRecordCodingKeys.self)
        cn = try values.decode(String.self, forKey: .cn)
        try super.init(from: decoder)
        privateObjectClass = ["container", "top"]
        privateHasSubordinates = "TRUE"
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: LDAPContainerRecordCodingKeys.self)
        try container.encode(cn, forKey: .cn)
    }
    
    init(entryUUID: String, cn: String) {
        self.cn = cn
        super.init(entryUUID: entryUUID)
        privateObjectClass = ["container", "top"]
        privateHasSubordinates = "TRUE"
    }
    
    override func valuesForField(_ field:String) -> [String]? {
        var key: LDAPContainerRecordCodingKeys?
        for k in iterateEnum(LDAPContainerRecordCodingKeys.self) {
            if k.rawValue.lowercased() == field.lowercased() {
                key = k
                break
            }
        }
        if let key = key {
            switch key {
            case .cn:
                return [cn]
            }
        } else {
            return super.valuesForField(field)
        }
    }
    
    static let userContainer: LDAPContainerRecord = {
        let container = LDAPContainerRecord(entryUUID: "20000000-0000-0000-0000-000000000001", cn: "users")
        container.privateParentContainer = LDAPDomainRecord.instanceDomain
        return container
    }()
    
    static let groupContainer: LDAPContainerRecord = {
        let container = LDAPContainerRecord(entryUUID: "20000000-0000-0000-0000-000000000002", cn: "groups")
        container.privateParentContainer = LDAPDomainRecord.instanceDomain
        return container
    }()
}


/**
 LDAP users are represented by this class. The class support Decodable from CouchDB JSON
 and Encodable to LDAP Gateway JSON
 */
class LDAPUserRecord: LDAPAbstractRecord {
    let uid: String
    let userPrincipalName: String
    let uidNumber: Int
    
    let mail: String?
    let givenName: String?
    let sn: String?
    let cn: String?
    
    static let fieldUsedInDN: LDAPFeild = .entryUUID
    
    override var fieldUsedInDN: LDAPFeild {
        get {
            return .entryUUID
        }
    }
    override var valueUsedInDN: String {
        get {
            return entryUUID
        }
    }
    
    enum LDAPUserRecordCodingKeys: String, CodingKey {
        case uidNumber
        case uid
        case userPrincipalName
        case mail
        case givenName
        case sn
        case cn
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: LDAPUserRecordCodingKeys.self)
        
        uidNumber = try values.decode(Int.self, forKey: .uidNumber)
        uid = try values.decode(String.self, forKey: .uid)
        userPrincipalName = try values.decode(String.self, forKey: .userPrincipalName)
        
        mail = try? values.decode(String.self, forKey: .mail)
        givenName = try? values.decode(String.self, forKey: .givenName)
        sn = try? values.decode(String.self, forKey: .sn)
        cn = try? values.decode(String.self, forKey: .cn)
        
        try super.init(from: decoder)
        privateObjectClass = ["inetOrgPerson", "posixAccount"]
        privateParentContainer = LDAPContainerRecord.userContainer
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: LDAPUserRecordCodingKeys.self)
        try container.encode(uidNumber, forKey: .uidNumber)
        try container.encode(uid, forKey: .uid)
        try container.encode(userPrincipalName, forKey: .userPrincipalName)
        try container.encode(mail, forKey: .mail)
        try container.encode(givenName, forKey: .givenName)
        try container.encode(sn, forKey: .sn)
        try container.encode(cn, forKey: .cn)
    }
    
    init(entryUUID: String, uid: String, userPrincipalName: String, uidNumber: Int, mail: String?, givenName: String?, sn: String?, cn: String?) {
        self.uid = uid
        self.userPrincipalName = userPrincipalName
        self.uidNumber = uidNumber
        self.mail = mail
        self.givenName = givenName
        self.sn = sn
        self.cn = cn
        super.init(entryUUID: entryUUID)
        privateObjectClass = ["inetOrgPerson", "posixAccount"]
        privateParentContainer = LDAPContainerRecord.userContainer
    }
    
    init(managedUser: ManagedUser) {
        uid = managedUser.shortname
        userPrincipalName = managedUser.principalName
        uidNumber = managedUser.numericID
        mail = managedUser.email
        givenName = managedUser.givenName
        sn = managedUser.surname
        cn = managedUser.fullName
        
        super.init(managedObject: managedUser)
    }
    
    override func valuesForField(_ field:String) -> [String]? {
        var key: LDAPUserRecordCodingKeys?
        for k in iterateEnum(LDAPUserRecordCodingKeys.self) {
            if k.rawValue.lowercased() == field.lowercased() {
                key = k
                break
            }
        }
        if let key = key {
            switch key {
            case .cn:
                if let cn = cn {
                    return [cn]
                } else {
                    return nil
                }
            case .uidNumber:
                return [String(uidNumber)]
            case .uid:
                return [uid]
            case .userPrincipalName:
                return [userPrincipalName]
            case .mail:
                if let mail = mail {
                    return [mail]
                } else {
                    return nil
                }
            case .givenName:
                if let givenName = givenName {
                    return [givenName]
                } else {
                    return nil
                }
            case .sn:
                if let sn = sn {
                    return [sn]
                } else {
                    return nil
                }
            }
        } else {
            return super.valuesForField(field)
        }
    }
}

// MARK: Langage extension to sapre some time

func iterateEnum<T: Hashable>(_: T.Type) -> AnyIterator<T> {
    var i = 0
    return AnyIterator {
        let next = withUnsafeBytes(of: &i) { $0.load(as: T.self) }
        if next.hashValue != i { return nil }
        i += 1
        return next
    }
}
