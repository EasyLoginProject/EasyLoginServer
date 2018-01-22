//
//  ManagedUserGroup.swift
//  DataProvider
//
//  Created by Frank on 03/01/2018.
//

import Foundation
import Extensions

public class ManagedUserGroup: ManagedObject {
    public fileprivate(set) var numericID: Int
    public fileprivate(set) var shortname: String
    public fileprivate(set) var commonName: String
    public fileprivate(set) var email: String?
    public fileprivate(set) var memberOf: [String]
    public fileprivate(set) var nestedGroups: [String]
    public fileprivate(set) var members: [String]
    
    public override var debugDescription: String {
        let objectAddress = String(format:"%2X", unsafeBitCast(self, to: Int.self))
        var desc = "<\(type(of:self)):\(objectAddress) numericID:\(numericID), shortname:\(shortname), commonName:\(commonName)"
        
        if let email = email {
            desc += ", email:\(email)"
        }
        
        desc += ", partialRepresentation:\(isPartialRepresentation)>"
        
        return desc
    }
    
    public override class func viewToListThemAll() -> String {
        return "all_usergroups"
    }
    
    enum ManagedUserGroupDatabaseCodingKeys: String, CodingKey {
        case numericID
        case shortname
        case commonName
        case email
        case memberOf
        case nestedGroups
        case members
    }
    
    enum ManagedUserGroupPartialDatabaseCodingKeys: String, CodingKey {
        case numericID
        case shortname
    }
    
    enum ManagedUserGroupAPICodingKeys: String, CodingKey {
        case numericID
        case shortname
        case commonName
        case email
        case memberOf
        case nestedGroups
        case members
    }
    
    
    fileprivate init(withNumericID numericID:Int, shortname:String, commonName:String, email:String?, memberOf:[String] = [], nestedGroups:[String] = [], members:[String] = []) {
        self.numericID = numericID
        self.shortname = shortname
        self.commonName = commonName
        self.email = email
        self.memberOf = memberOf
        self.nestedGroups = nestedGroups
        self.members = members
        super.init()
        recordType = "usergroup"
    }
    
    public required init(from decoder: Decoder) throws {
        let codingStrategy = decoder.userInfo[.managedObjectCodingStrategy] as? ManagedObjectCodingStrategy
        
        switch codingStrategy {
        case .databaseEncoding?, .none:
            let container = try decoder.container(keyedBy: ManagedUserGroupDatabaseCodingKeys.self)
            numericID = try container.decode(Int.self, forKey: .numericID)
            shortname = try container.decode(String.self, forKey: .shortname)
            commonName = try container.decode(String.self, forKey: .commonName)
            email = try container.decode(String?.self, forKey: .email)
            memberOf = try container.decode([String].self, forKey: .memberOf)
            nestedGroups = try container.decode([String].self, forKey: .nestedGroups)
            members = try container.decode([String].self, forKey: .members)
            
        case .briefEncoding?:
            let container = try decoder.container(keyedBy: ManagedUserGroupPartialDatabaseCodingKeys.self)
            numericID = try container.decode(Int.self, forKey: .numericID)
            shortname = try container.decode(String.self, forKey: .shortname)
            commonName = "" // FIXME: invalid?
            memberOf = []
            nestedGroups = []
            members = []
            
        case .apiEncoding(_)?:
            throw EasyLoginError.debug("not implemented")
        }
        
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        let codingStrategy = encoder.userInfo[.managedObjectCodingStrategy] as? ManagedObjectCodingStrategy
        
        switch codingStrategy {
        case .databaseEncoding?, .none:
            var container = encoder.container(keyedBy: ManagedUserGroupDatabaseCodingKeys.self)
            try container.encode(numericID, forKey: .numericID)
            try container.encode(shortname, forKey: .shortname)
            try container.encode(commonName, forKey: .commonName)
            try container.encode(email, forKey: .email)
            try container.encode(memberOf, forKey: .memberOf)
            try container.encode(nestedGroups, forKey: .nestedGroups)
            try container.encode(members, forKey: .members)
            
        case .briefEncoding?:
            var container = encoder.container(keyedBy: ManagedUserGroupPartialDatabaseCodingKeys.self)
            try container.encode(numericID, forKey: .numericID)
            try container.encode(shortname, forKey: .shortname)
            
        case .apiEncoding(let view)?:
            var container = encoder.container(keyedBy: ManagedUserGroupAPICodingKeys.self)
            try container.encode(numericID, forKey: .numericID)
            try container.encode(shortname, forKey: .shortname)
            if view == .full {
                try container.encode(commonName, forKey: .commonName)
                if let email = email {
                    try container.encode(email, forKey: .email)
                }
                try container.encode(memberOf, forKey: .memberOf)
                try container.encode(nestedGroups, forKey: .nestedGroups)
                try container.encode(members, forKey: .members)
            }
        }
        try super.encode(to: encoder)
    }
}

public class MutableManagedUserGroup : ManagedUserGroup, MutableManagedObject {
    public fileprivate(set) var hasBeenEdited = false
    
    public override var debugDescription: String {
        
        let objectAddress = String(format:"%2X", unsafeBitCast(self, to: Int.self))
        var desc = "<\(type(of:self)):\(objectAddress) numericID:\(numericID), shortname:\(shortname), commonName:\(commonName)"
        
        if let email = email {
            desc += ", email:\(email)"
        }
        
        desc += ", partialRepresentation:\(isPartialRepresentation)>"
        desc += ", hasBeenEdited:\(hasBeenEdited)>"
        
        return desc
    }
    
    enum MutableManagedUserGroupUpdateError: Error {
        case invalidShortname
        case invalidEmail
    }
    
    public override init(withNumericID numericID:Int, shortname:String, commonName:String, email:String?, memberOf:[String] = [], nestedGroups:[String] = [], members:[String] = []) {
        hasBeenEdited = true
        super.init(withNumericID: numericID, shortname: shortname, commonName: commonName, email: email, memberOf: memberOf, nestedGroups: nestedGroups, members: members)
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
    
    public func setShortname(_ value:String) throws {
        guard value != shortname else {
            return
        }
        
        guard value.range(of: "^[a-z_][a-z0-9_-]{0,30}$", options: .regularExpression, range: nil, locale: nil) != nil else {
            throw MutableManagedUserGroupUpdateError.invalidShortname
        }
        
        shortname = value
        hasBeenEdited = true
    }
    
    public func setCommonName(_ value:String) {
        guard value != commonName else {
            return
        }
        
        commonName = value
        hasBeenEdited = true
    }
    
    public func setEmail(_ value:String) throws {
        guard value != email else {
            return
        }
        
        guard value.range(of: "^[a-z0-9_.-]+@[A-Za-z0-9.-]+$", options: .regularExpression, range: nil, locale: nil) != nil else {
            throw MutableManagedUserGroupUpdateError.invalidEmail
        }
        
        email = value
        hasBeenEdited = true
    }
    
    public func clearEmail() {
        guard email != nil else {
            return
        }
        email = nil
        hasBeenEdited = true
    }
    
    public func setOwners(_ value: [String]) {
        guard value != memberOf else {
            return
        }
        memberOf = value
        hasBeenEdited = true
    }
    
    public func setNestedGroups(_ value: [String]) {
        guard value != nestedGroups else {
            return
        }
        nestedGroups = value
        hasBeenEdited = true
    }
    
    public func setMembers(_ value: [String]) {
        guard value != members else {
            return
        }
        members = value
        hasBeenEdited = true
    }
    
    override class func requireFullObject() -> Bool {
        return true
    }
}
