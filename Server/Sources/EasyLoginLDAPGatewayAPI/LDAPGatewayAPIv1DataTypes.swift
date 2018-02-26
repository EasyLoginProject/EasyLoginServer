//
//  LDAPGatewayAPIv1DataTypes.swift
//  EasyLoginPackageDescription
//
//  Created by Yoann Gini on 29/12/2017.
//

import Foundation
import DataProvider
import Dispatch
import LoggerAPI



// MARK: - Common LDAP API

enum LDAPAPIError: Error {
    case unsupportedRequest
    case recordNotFound
}

func iterateEnum<T: Hashable>(_: T.Type) -> AnyIterator<T> {
    var i = 0
    return AnyIterator {
        let next = withUnsafeBytes(of: &i) { $0.load(as: T.self) }
        if next.hashValue != i { return nil }
        i += 1
        return next
    }
}


// MARK: - Codable objects for LDAP authentication requests

/**
 Represents an LDAP authentication request once converted to LDAP by the Perl gateway.
 Supports only simple authentication at this time.
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
 Represents all kinds of complex filter requests provided by the Perl gateway.
 Filters can be nested and agregated via an operator (and, or, not),
 so LDAPFilter needs to be a class that can reference other instances.
 
 LDAPFilter aren't provided directly by the LDAP gateway, they come via a LDAPSearchRequest
 that provides context information for the lookup.
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
     Returns an enum-based value representing the filter type.
     All operation having different use cases based on the filter type must use this value
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
     - returns: a new array representing all records which passed all the tests.
     */
    func filter(records: [LDAPAbstractRecord]) -> [LDAPAbstractRecord]? {
        Log.entry("Filtering operation")
        defer {
            Log.exit("Filtering operation")
        }
        switch nodeType() {
        case .and:
            Log.info("AND operation")
            if let nestedFilters = and {
                var combinedResult = [LDAPAbstractRecord]()
                var firstLoop = true
                Log.debug("Iterating over nested filters for AND operation")
                for nestedFilter in nestedFilters {
                    if let nestedResult = nestedFilter.filter(records: records) {
                        if firstLoop {
                            Log.debug("First loop done")
                            combinedResult.append(contentsOf: nestedResult)
                            firstLoop = false
                        } else {
                            Log.debug("New loop done")
                            combinedResult = combinedResult.filter({ (recordFromCombinedResult) -> Bool in
                                return nestedResult.contains(recordFromCombinedResult)
                            })
                        }
                    } else {
                        Log.error("Nested filter returned nil, unsupported scenario")
                        return nil
                    }
                }
                Log.debug("Iteration done, returning result")
                return combinedResult
            }
            
        case .or:
            Log.info("OR operation")
            if let nestedFilters = or {
                var combinedResult = [LDAPAbstractRecord]()
                Log.debug("Iterating over nested filters for OR operation")
                for nestedFilter in nestedFilters {
                    if let nestedResult = nestedFilter.filter(records: records) {
                        combinedResult.append(contentsOf: nestedResult)
                    } else {
                        Log.error("Nested filter returned nil, unsupported scenario")
                        return nil
                    }
                }
                
                Log.debug("Iteration done, returning result")
                return combinedResult
            }
            
        case .not:
            Log.info("NOT operation")
            if let nestedFilter = not {
                if let resultToSkip = nestedFilter.filter(records: records) {
                    Log.debug("Inverting nested result based on initial records")
                    return records.filter({ (recordToEvaluate) -> Bool in
                        return !resultToSkip.contains(recordToEvaluate)
                    })
                } else {
                    return nil
                }
            }
            
        case .equalityMatch:
            Log.info("EqualityMatch operation")
            if let equalityMatch = equalityMatch {
                Log.debug("Checking every records using valuesForField func to get access to values")
                return records.filter({ (recordToCheck) -> Bool in
                    if let testedValues = recordToCheck.valuesForField(equalityMatch.attributeDesc) {
                        for testedValue in testedValues {
                            if testedValue.lowercased() == equalityMatch.assertionValue.lowercased() {
                                return true
                            }
                        }
                    }
                    return false
                })
            }
            
        case .substrings:
            Log.info("Substrings operation")
            if let substringsFilter = substrings {
                Log.debug("Checking every records using valuesForField func to get access to values")
                return records.filter({ (recordToCheck) -> Bool in
                    if let valuesToEvaluate = recordToCheck.valuesForField(substringsFilter.type) {
                        for valueToEvaluate in valuesToEvaluate {
                            for substrings in substringsFilter.substrings {
                                for (matchType, value) in substrings {
                                    switch matchType {
                                    case "any":
                                        Log.info("Substrings match anywhere")
                                        if valueToEvaluate.lowercased().contains(value.lowercased()) {
                                            return true
                                        }
                                    case "initial":
                                        Log.info("Substrings match prefix")
                                        if valueToEvaluate.lowercased().hasPrefix(value.lowercased()) {
                                            return true
                                        }
                                    case "final":
                                        Log.info("Substrings match suffix")
                                        if valueToEvaluate.lowercased().hasSuffix(value.lowercased()) {
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
            Log.info("Present operation")
            if let mustBePresent = present {
                Log.debug("Check if record as value for field \(mustBePresent)")
                return records.filter({ (recordToCheck) -> Bool in
                    if let _ = recordToCheck.valuesForField(mustBePresent){
                        return true
                    } else {
                        return false
                    }
                })
            }
            
        case .unkown:
            Log.error("Unsupported operation")
            return nil
        }
        return nil
    }
    
}

/**
 An LDAPSearchRequest represents the root object sent via the Perl gateway when
 looking for a record.
 
 Filters need to be applied to all objects grabbed by the combination of the baseObject and the scope.
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
 Base object for all records that can be requested by the client. Provides some basics for DN construction, object comparison, filtering process…
 */
class LDAPAbstractRecord : Codable, Equatable {
    // Record properties
    let entryUUID: String
    
    // Record LDAP behavior that need to be overrided
    var objectClass: [String] {
        get {
            return []
        }
    }
    
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
    
    var privateParentContainer: LDAPAbstractRecord?
    
    fileprivate (set) var hasSubordinates = "TRUE"
    
    func valuesForField(_ field:String) -> [String]? {
        Log.debug("LDAPAbstractRecord / Looking for value for field \(field)")
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
            Log.debug("Unsuported key")
            return nil
        }
    }
    
    // Record LDAP shared behavior
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
    
    static func ==(lhs: LDAPAbstractRecord, rhs: LDAPAbstractRecord) -> Bool {
        return lhs.entryUUID == rhs.entryUUID
    }
    
    // Record implementation
    enum LDAPAbstractRecordCodingKeys: String, CodingKey {
        case entryUUID
        case objectClass
        case hasSubordinates
        case dn
    }
    
    required init(from decoder: Decoder) throws {
        assertionFailure("LDAP record representation cannot initiated from encoded representation.")
        throw LDAPAPIError.unsupportedRequest
    }
    
    func encode(to encoder: Encoder) throws {
        Log.info("Encoding LDAPAbstractRecord fields")
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
        Log.info("Initiating LDAPAbstractRecord with managedObject")
        entryUUID = managedObject.uuid
    }
}

/**
 The LDAP Root DSE is a specific object with dn set to "".
 It will be used by LDAP clients to understand the global context of our LDAP realm.
 */
class LDAPRootDSERecord: LDAPAbstractRecord {
    // Record properties
    let namingContexts: [String]?
    let subschemaSubentry: [String]?
    let supportedLDAPVersion: [String]?
    let supportedSASLMechanisms: [String]?
    let supportedExtension: [String]?
    let supportedControl: [String]?
    let supportedFeatures: [String]?
    let vendorName: [String]?
    let vendorVersion: [String]?
    
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
    
    // Record LDAP behavior that need to be overrided
    override var objectClass: [String] {
        get {
            return ["top"]
        }
    }
    
    override var dn: String {
        get {
            return "" // Special case, Root DSE is he no DN object
        }
    }
    
    override func valuesForField(_ field:String) -> [String]? {
        Log.debug("LDAPRootDSERecord / Looking for value for field \(field)")
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
            Log.debug("Unsuported key at LDAPRootDSERecord level, trying ancestor")
            return super.valuesForField(field)
        }
    }
    
    // Record implementation
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
        Log.info("Encoding LDAPRootDSERecord fields")
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
        assertionFailure("LDAP record representation cannot initiated from encoded representation.")
        throw LDAPAPIError.unsupportedRequest
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
    }
}

/**
 LDAP domain is the root object of our LDAP realm, dn is something like "dc=easylogin,dc=proxy".
 */
class LDAPDomainRecord: LDAPAbstractRecord {
    // Record properties
    let dc: String
    
    static let fieldUsedInDN: LDAPFeild = .dc
    
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
    
    // Record LDAP behavior that need to be overrided
    override var objectClass: [String] {
        get {
            return ["domain", "top"]
        }
    }
    
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
    
    override func valuesForField(_ field:String) -> [String]? {
        Log.debug("LDAPDomainRecord / Looking for value for field \(field)")
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
            Log.debug("Unsuported key at LDAPDomainRecord level, trying ancestor")
            return super.valuesForField(field)
        }
    }
    
    // Record implementation
    enum LDAPDomainRecordCodingKeys: String, CodingKey {
        case dc
    }
    
    required init(from decoder: Decoder) throws {
        assertionFailure("LDAP record representation cannot initiated from encoded representation.")
        throw LDAPAPIError.unsupportedRequest
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        Log.info("Encoding LDAPDomainRecord fields")
        var container = encoder.container(keyedBy: LDAPDomainRecordCodingKeys.self)
        try container.encode(dc, forKey: .dc)
    }
    
    init(entryUUID: String, dc: String) {
        self.dc = dc
        super.init(entryUUID: entryUUID)
    }
}

/**
 An LDAP container is a node object in the tree (when records are the leaf).
 Containers have basic class and dn plus a common name. This is usually used
 to split groups and users.
 */
class LDAPContainerRecord: LDAPAbstractRecord {
    // Record properties
    let cn: String
    
    static let fieldUsedInDN: LDAPFeild = .cn
    
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
    
    // Record LDAP behavior that need to be overrided
    override var objectClass: [String] {
        get {
            return ["container", "top"]
        }
    }
    
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
    
    override func valuesForField(_ field:String) -> [String]? {
        Log.debug("LDAPContainerRecord / Looking for value for field \(field)")
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
            Log.debug("Unsuported key at LDAPContainerRecord level, trying ancestor")
            return super.valuesForField(field)
        }
    }
    
    // Record implementation
    enum LDAPContainerRecordCodingKeys: String, CodingKey {
        case cn
    }
    
    required init(from decoder: Decoder) throws {
        assertionFailure("LDAP record representation cannot initiated from encoded representation.")
        throw LDAPAPIError.unsupportedRequest
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        Log.info("Encoding LDAPContainerRecord fields")
        var container = encoder.container(keyedBy: LDAPContainerRecordCodingKeys.self)
        try container.encode(cn, forKey: .cn)
    }
    
    init(entryUUID: String, cn: String) {
        self.cn = cn
        super.init(entryUUID: entryUUID)
    }
}


/**
 LDAP users are represented by this class. The class support Decodable from CouchDB JSON
 and Encodable to LDAP Gateway JSON
 */
class LDAPUserRecord: LDAPAbstractRecord {
    let managedUser: ManagedUser
    
    // Record properties
    let uid: String
    let userPrincipalName: String
    let uidNumber: Int
    
    let mail: String?
    let givenName: String?
    let sn: String?
    let cn: String?
    
    lazy var memberOfByDN: [String]? = {
        do {
            return try managedUser.memberOf.map { (recordID) -> String in
                Log.info("Lazy loading of LDAPUserRecord.memberOfByDN, mapping \(recordID) ")
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUserGroup: ManagedUserGroup?
                
                managedUser.dataProvider!.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordID, completion: { (userGroup, error) in
                    Log.debug("Lazy loading got DB result")
                    relatedUserGroup = userGroup
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUserGroup = relatedUserGroup {
                    Log.debug("Related group found")
                    return LDAPUserGroupRecord(managedUserGroup: relatedUserGroup).dn
                } else {
                    Log.error("Related group not found")
                    throw LDAPAPIError.recordNotFound
                }
            }
        } catch {
            //TODO: YGI we need to define what to do when a related record isn't found. Is it group info who's incoherent or database who's out of service?
            return nil
        }
    }()
    
    lazy var memberOfByShortname: [String]? = {
        do {
            return try managedUser.memberOf.map { (recordID) -> String in
                Log.info("Lazy loading of LDAPUserRecord.memberOfByShortname, mapping \(recordID) ")
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUserGroup: ManagedUserGroup?
                managedUser.dataProvider!.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordID, completion: { (userGroup, error) in
                    Log.debug("Lazy loading got DB result")
                    relatedUserGroup = userGroup
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUserGroup = relatedUserGroup {
                    Log.debug("Related group found")
                    return relatedUserGroup.shortname
                } else {
                    Log.error("Related group not found")
                    throw LDAPAPIError.recordNotFound
                }
            }
        } catch {
            //TODO: YGI we need to define what to do when a related record isn't found. Is it group info who's incoherent or database who's out of service?
            return nil
        }
    }()
    
    var flattenMemberOfByShortname: [String] {
        get {
            Log.info("Computing LDAPUserRecord.flattenMemberOfByShortname")
            var flattenMemberOfByShortname = [String]()
            
            if let memberOfByShortname = self.memberOfByShortname {
                flattenMemberOfByShortname += memberOfByShortname
            }
            
            var inheritedMemberOfByShortname = [String]()
            
            for recordID in self.managedUser.memberOf {
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUserGroup: ManagedUserGroup?
                self.managedUser.dataProvider!.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordID, completion: { (userGroup, error) in
                    Log.debug("Computing got DB result")
                    relatedUserGroup = userGroup
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUserGroup = relatedUserGroup {
                    inheritedMemberOfByShortname += LDAPUserGroupRecord(managedUserGroup: relatedUserGroup).flattenMemberOfByShortname
                }
            }
            
            flattenMemberOfByShortname += inheritedMemberOfByShortname
            
            return flattenMemberOfByShortname
        }
    }
    
    static let fieldUsedInDN: LDAPFeild = .entryUUID
    
    // Record LDAP behavior that need to be overrided
    override var objectClass: [String] {
        get {
            return ["inetOrgPerson", "easylogin-user"]
        }
    }
    
    override var parentContainer: LDAPAbstractRecord? {
        get {
            return LDAPContainerRecord.userContainer
        }
    }
    
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
    
    override func valuesForField(_ field:String) -> [String]? {
        Log.debug("LDAPUserRecord / Looking for value for field \(field)")
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
                
            case .memberOfByDN:
                return memberOfByDN
            case .memberOfByShortname:
                return memberOfByShortname
                
            case .flattenMemberOfByShortname:
                return flattenMemberOfByShortname
            }
        } else {
            Log.debug("Unsuported key at LDAPUserRecord level, trying ancestor")
            return super.valuesForField(field)
        }
    }
    
    // Record implementation
    enum LDAPUserRecordCodingKeys: String, CodingKey {
        case uidNumber
        case uid
        case userPrincipalName
        case mail
        case givenName
        case sn
        case cn
        case memberOfByDN
        case memberOfByShortname
        case flattenMemberOfByShortname
    }
    
    required init(from decoder: Decoder) throws {
        assertionFailure("LDAP record representation cannot initiated from encoded representation.")
        throw LDAPAPIError.unsupportedRequest
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        Log.info("Encoding LDAPUserRecord fields")
        var container = encoder.container(keyedBy: LDAPUserRecordCodingKeys.self)
        try container.encode(uidNumber, forKey: .uidNumber)
        try container.encode(uid, forKey: .uid)
        try container.encode(userPrincipalName, forKey: .userPrincipalName)
        try container.encode(mail, forKey: .mail)
        try container.encode(givenName, forKey: .givenName)
        try container.encode(sn, forKey: .sn)
        try container.encode(cn, forKey: .cn)
        try container.encode(memberOfByDN, forKey: .memberOfByDN)
        try container.encode(memberOfByShortname, forKey: .memberOfByShortname)
        try container.encode(flattenMemberOfByShortname, forKey: .flattenMemberOfByShortname)
    }
    
    init(managedUser: ManagedUser) {
        Log.info("Initiating LDAPUserRecord with managedObject")
        self.managedUser = managedUser
        
        uid = managedUser.shortname
        userPrincipalName = managedUser.principalName
        uidNumber = managedUser.numericID
        mail = managedUser.email
        givenName = managedUser.givenName
        sn = managedUser.surname
        cn = managedUser.fullName
        
        super.init(managedObject: managedUser)
        hasSubordinates = "FALSE"
    }
}


/**
 LDAP usergroups are represented by this class. The class support Decodable from CouchDB JSON
 and Encodable to LDAP Gateway JSON
 */
class LDAPUserGroupRecord: LDAPAbstractRecord {
    let managedUserGroup: ManagedUserGroup
    
    // Record properties
    let uid: String
    let uidNumber: Int
    
    let mail: String?
    let cn: String?
    
    lazy var nestedGroupsByDN: [String]? = {
        do {
            return try managedUserGroup.nestedGroups.map { (recordID) -> String in
                Log.info("Lazy loading of LDAPUserGroupRecord.nestedGroupsByDN, mapping \(recordID) ")
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUserGroup: ManagedUserGroup?
                managedUserGroup.dataProvider!.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordID, completion: { (userGroup, error) in
                    Log.debug("Lazy loading got DB result")
                    relatedUserGroup = userGroup
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUserGroup = relatedUserGroup {
                    Log.debug("Related group found")
                    return LDAPUserGroupRecord(managedUserGroup: relatedUserGroup).dn
                } else {
                    Log.error("Related group not found")
                    throw LDAPAPIError.recordNotFound
                }
            }
        } catch {
            //TODO: YGI we need to define what to do when a related record isn't found. Is it group info who's incoherent or database who's out of service?
            return nil
        }
    }()
    
    lazy var nestedGroupByShortname: [String]? = {
        do {
            return try managedUserGroup.nestedGroups.map { (recordID) -> String in
                Log.info("Lazy loading of LDAPUserGroupRecord.nestedGroupByShortname, mapping \(recordID) ")
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUserGroup: ManagedUserGroup?
                managedUserGroup.dataProvider!.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordID, completion: { (userGroup, error) in
                    Log.debug("Lazy loading got DB result")
                    relatedUserGroup = userGroup
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUserGroup = relatedUserGroup {
                    Log.debug("Related group found")
                    return relatedUserGroup.shortname
                } else {
                    Log.error("Related group not found")
                    throw LDAPAPIError.recordNotFound
                }
            }
        } catch {
            //TODO: YGI we need to define what to do when a related record isn't found. Is it group info who's incoherent or database who's out of service?
            return nil
        }
    }()
    
    lazy var memberByDN: [String]? = {
        do {
            return try managedUserGroup.members.map { (recordID) -> String in
                Log.info("Lazy loading of LDAPUserGroupRecord.memberByDN, mapping \(recordID) ")
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUser: ManagedUser?
                managedUserGroup.dataProvider!.completeManagedObject(ofType: ManagedUser.self, withUUID: recordID, completion: { (user, error) in
                    Log.debug("Lazy loading got DB result")
                    relatedUser = user
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUser = relatedUser {
                    Log.debug("Related user found")
                    return LDAPUserRecord(managedUser: relatedUser).dn
                } else {
                    Log.error("Related user not found")
                    throw LDAPAPIError.recordNotFound
                }
            }
        } catch {
            //TODO: YGI we need to define what to do when a related record isn't found. Is it group info who's incoherent or database who's out of service?
            return nil
        }
    }()
    
    lazy var memberByShortname: [String]? = {
        do {
            return try managedUserGroup.members.map { (recordID) -> String in
                Log.info("Lazy loading of LDAPUserGroupRecord.memberByShortname, mapping \(recordID) ")
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUser: ManagedUser?
                managedUserGroup.dataProvider!.completeManagedObject(ofType: ManagedUser.self, withUUID: recordID, completion: { (user, error) in
                    Log.debug("Lazy loading got DB result")
                    relatedUser = user
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUser = relatedUser {
                    Log.debug("Related user found")
                    return relatedUser.shortname
                } else {
                    Log.error("Related user not found")
                    throw LDAPAPIError.recordNotFound
                }
            }
        } catch {
            //TODO: YGI we need to define what to do when a related record isn't found. Is it group info who's incoherent or database who's out of service?
            return nil
        }
    }()
    
    lazy var memberOfByDN: [String]? = {
        do {
            return try managedUserGroup.memberOf.map { (recordID) -> String in
                Log.info("Lazy loading of LDAPUserGroupRecord.memberOfByDN, mapping \(recordID) ")
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUserGroup: ManagedUserGroup?
                managedUserGroup.dataProvider!.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordID, completion: { (userGroup, error) in
                    Log.debug("Lazy loading got DB result")
                    relatedUserGroup = userGroup
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUserGroup = relatedUserGroup {
                    Log.debug("Related group found")
                    return LDAPUserGroupRecord(managedUserGroup: relatedUserGroup).dn
                } else {
                    Log.error("Related group not found")
                    throw LDAPAPIError.recordNotFound
                }
            }
        } catch {
            //TODO: YGI we need to define what to do when a related record isn't found. Is it group info who's incoherent or database who's out of service?
            return nil
        }
    }()
    
    lazy var memberOfByShortname: [String]? = {
        do {
            return try managedUserGroup.memberOf.map { (recordID) -> String in
                Log.info("Lazy loading of LDAPUserGroupRecord.memberOfByShortname, mapping \(recordID) ")
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUserGroup: ManagedUserGroup?
                managedUserGroup.dataProvider!.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordID, completion: { (userGroup, error) in
                    Log.debug("Lazy loading got DB result")
                    relatedUserGroup = userGroup
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUserGroup = relatedUserGroup {
                    Log.debug("Related group found")
                    return relatedUserGroup.shortname
                } else {
                    Log.error("Related group not found")
                    throw LDAPAPIError.recordNotFound
                }
            }
        } catch {
            //TODO: YGI we need to define what to do when a related record isn't found. Is it group info who's incoherent or database who's out of service?
            return nil
        }
    }()
    
    var flattenNestedGroupByShortname: [String]  {
        get {
            Log.info("Computing LDAPUserGroupRecord.flattenNestedGroupByShortname")
            var flattenNestedGroupByShortname = [String]()
            
            if let nestedGroupByShortname = self.nestedGroupByShortname {
                flattenNestedGroupByShortname += nestedGroupByShortname
            }
            
            var inheritedNestedGroupByShortname = [String]()
            
            for recordID in self.managedUserGroup.nestedGroups {
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUserGroup: ManagedUserGroup?
                self.managedUserGroup.dataProvider!.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordID, completion: { (userGroup, error) in
                    Log.debug("Computing got DB result")
                    relatedUserGroup = userGroup
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUserGroup = relatedUserGroup {
                    inheritedNestedGroupByShortname += LDAPUserGroupRecord(managedUserGroup: relatedUserGroup).flattenNestedGroupByShortname
                }
            }
            
            flattenNestedGroupByShortname += inheritedNestedGroupByShortname
            
            return flattenNestedGroupByShortname
        }
    }
    
    var flattenMemberByShortname: [String] {
        get {
            Log.info("Computing LDAPUserGroupRecord.flattenMemberByShortname")
            var flattenMemberByShortname = [String]()
            
            if let memberByShortname = self.memberByShortname {
                flattenMemberByShortname += memberByShortname
            }
            
            var inheritedMemberByShortname = [String]()
            
            for recordID in self.managedUserGroup.nestedGroups {
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUserGroup: ManagedUserGroup?
                self.managedUserGroup.dataProvider!.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordID, completion: { (userGroup, error) in
                    Log.debug("Computing got DB result")
                    relatedUserGroup = userGroup
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUserGroup = relatedUserGroup {
                    inheritedMemberByShortname += LDAPUserGroupRecord(managedUserGroup: relatedUserGroup).flattenMemberByShortname
                }
            }
            
            flattenMemberByShortname += inheritedMemberByShortname
            
            return flattenMemberByShortname
        }
    }
    
    var flattenMemberOfByShortname: [String] {
        get {
            Log.info("Computing LDAPUserGroupRecord.flattenMemberOfByShortname")
            var flattenMemberOfByShortname = [String]()
            
            if let memberOfByShortname = self.memberOfByShortname {
                flattenMemberOfByShortname += memberOfByShortname
            }
            
            var inheritedMemberOfByShortname = [String]()
            
            for recordID in self.managedUserGroup.memberOf {
                let semaphore = DispatchSemaphore(value: 0)
                var relatedUserGroup: ManagedUserGroup?
                self.managedUserGroup.dataProvider!.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordID, completion: { (userGroup, error) in
                    Log.debug("Computing got DB result")
                    relatedUserGroup = userGroup
                    semaphore.signal()
                })
                semaphore.wait()
                
                if let relatedUserGroup = relatedUserGroup {
                    inheritedMemberOfByShortname += LDAPUserGroupRecord(managedUserGroup: relatedUserGroup).flattenMemberOfByShortname
                }
            }
            
            flattenMemberOfByShortname += inheritedMemberOfByShortname
            
            return flattenMemberOfByShortname
        }
    }
    
    static let fieldUsedInDN: LDAPFeild = .entryUUID
    
    // Record LDAP behavior that need to be overrided
    override var objectClass: [String] {
        get {
            return ["easylogin-group"]
        }
    }
    
    override var parentContainer: LDAPAbstractRecord? {
        get {
            return LDAPContainerRecord.groupContainer
        }
    }
    
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
    
    override func valuesForField(_ field:String) -> [String]? {
        Log.debug("LDAPUserGroupRecord / Looking for value for field \(field)")
        var key: LDAPUserGroupRecordCodingKeys?
        for k in iterateEnum(LDAPUserGroupRecordCodingKeys.self) {
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
            case .mail:
                if let mail = mail {
                    return [mail]
                } else {
                    return nil
                }
                
            case .nestedGroupsByDN:
                return nestedGroupsByDN
            case .nestedGroupByShortname:
                return nestedGroupByShortname
                
            case .memberByDN:
                return memberByDN
            case .memberByShortname:
                return memberByShortname
            case .memberOfByShortname:
                return memberOfByShortname
                
            case .flattenNestedGroupByShortname:
                return flattenNestedGroupByShortname
            case .flattenMemberByShortname:
                return flattenMemberByShortname
            case .flattenMemberOfByShortname:
                return flattenMemberOfByShortname
            }
        } else {
            Log.debug("Unsuported key at LDAPUserGroupRecord level, trying ancestor")
            return super.valuesForField(field)
        }
    }
    
    // Record implementation
    enum LDAPUserGroupRecordCodingKeys: String, CodingKey {
        case uidNumber
        case uid
        case mail
        case cn
        
        case nestedGroupsByDN
        case nestedGroupByShortname
        
        case memberByDN
        case memberByShortname
        case memberOfByShortname
        
        case flattenNestedGroupByShortname
        case flattenMemberByShortname
        case flattenMemberOfByShortname
    }
    
    required init(from decoder: Decoder) throws {
        assertionFailure("LDAP record representation cannot initiated from encoded representation.")
        throw LDAPAPIError.unsupportedRequest
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        Log.info("Encoding LDAPUserGroupRecord fields")
        var container = encoder.container(keyedBy: LDAPUserGroupRecordCodingKeys.self)
        try container.encode(uidNumber, forKey: .uidNumber)
        try container.encode(uid, forKey: .uid)
        try container.encode(mail, forKey: .mail)
        try container.encode(cn, forKey: .cn)
        
        try container.encode(nestedGroupsByDN, forKey: .nestedGroupsByDN)
        try container.encode(nestedGroupByShortname, forKey: .nestedGroupByShortname)
        
        try container.encode(memberByDN, forKey: .memberByDN)
        try container.encode(memberByShortname, forKey: .memberByShortname)
        try container.encode(memberOfByShortname, forKey: .memberOfByShortname)
        
        try container.encode(flattenNestedGroupByShortname, forKey: .flattenNestedGroupByShortname)
        try container.encode(flattenMemberByShortname, forKey: .flattenMemberByShortname)
        try container.encode(flattenMemberOfByShortname, forKey: .flattenMemberOfByShortname)
    }
    
    init(managedUserGroup: ManagedUserGroup) {
        Log.info("Initiating LDAPUserGroupRecord with managedObject")
        self.managedUserGroup = managedUserGroup
        
        uid = managedUserGroup.shortname
        uidNumber = managedUserGroup.numericID
        mail = managedUserGroup.email
        cn = managedUserGroup.commonName
        
        super.init(managedObject: managedUserGroup)
        hasSubordinates = "FALSE"
    }
}
