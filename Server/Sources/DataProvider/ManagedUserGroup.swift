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
    public fileprivate(set) var memberOf: [ManagedObjectRecordID]
    public fileprivate(set) var nestedGroups: [ManagedObjectRecordID]
    public fileprivate(set) var members: [ManagedObjectRecordID]
    
    public override var debugDescription: String {
        let objectAddress = String(format:"%2X", unsafeBitCast(self, to: Int.self))
        var desc = "<\(type(of:self)):\(objectAddress) numericID:\(numericID), shortname:\(shortname), commonName:\(commonName)"
        
        if let email = email {
            desc += ", email:\(email)"
        }
        
        desc += ", memberOf:\(memberOf)"
        desc += ", nestedGroups:\(nestedGroups)"
        desc += ", members:\(members)"
        
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
    
    fileprivate init(withDataProvider dataProvider: DataProvider, numericID:Int, shortname:String, commonName:String, email:String?, memberOf:[ManagedObjectRecordID] = [], nestedGroups:[ManagedObjectRecordID] = [], members:[ManagedObjectRecordID] = []) {
        self.numericID = numericID
        self.shortname = shortname
        self.commonName = commonName
        self.email = email
        self.memberOf = memberOf
        self.nestedGroups = nestedGroups
        self.members = members
        super.init(withDataProvider: dataProvider)
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
            memberOf = try container.decode([ManagedObjectRecordID].self, forKey: .memberOf)
            nestedGroups = try container.decode([ManagedObjectRecordID].self, forKey: .nestedGroups)
            members = try container.decode([ManagedObjectRecordID].self, forKey: .members)
            
        case .briefEncoding?:
            let container = try decoder.container(keyedBy: ManagedUserGroupPartialDatabaseCodingKeys.self)
            numericID = try container.decode(Int.self, forKey: .numericID)
            shortname = try container.decode(String.self, forKey: .shortname)
            commonName = "" // FIXME: invalid?
            memberOf = []
            nestedGroups = []
            members = []
        }
        
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ManagedUserGroupDatabaseCodingKeys.self)
        try container.encode(numericID, forKey: .numericID)
        try container.encode(shortname, forKey: .shortname)
        try container.encode(commonName, forKey: .commonName)
        try container.encode(email, forKey: .email)
        try container.encode(memberOf, forKey: .memberOf)
        try container.encode(nestedGroups, forKey: .nestedGroups)
        try container.encode(members, forKey: .members)
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
        
        desc += ", memberOf:\(memberOf)"
        desc += ", nestedGroups:\(nestedGroups)"
        desc += ", members:\(members)"
        
        desc += ", partialRepresentation:\(isPartialRepresentation)>"
        desc += ", hasBeenEdited:\(hasBeenEdited)>"
        
        return desc
    }
    
    enum MutableManagedUserGroupUpdateError: Error {
        case invalidShortname
        case invalidEmail
    }
    
    public override init(withDataProvider dataProvider: DataProvider, numericID:Int, shortname:String, commonName:String, email:String?, memberOf:[ManagedObjectRecordID] = [], nestedGroups:[ManagedObjectRecordID] = [], members:[ManagedObjectRecordID] = []) {
        hasBeenEdited = true
        super.init(withDataProvider: dataProvider, numericID: numericID, shortname: shortname, commonName: commonName, email: email, memberOf: memberOf, nestedGroups: nestedGroups, members: members)
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
    
    public func setRelationships(memberOf: [ManagedObjectRecordID], nestedGroups: [ManagedObjectRecordID], members: [ManagedObjectRecordID], completion: @escaping (Error?) -> Void) {
        guard let dataProvider = dataProvider else {
            completion(EasyLoginError.internalServerError)
            return
        }
        let initialOwners = self.memberOf
        let finalOwners = memberOf
        let (addedOwnerIDs, removedOwnerIDs) = finalOwners.difference(from: initialOwners)
        let initialNestedGroups = self.nestedGroups
        let finalNestedGroups = nestedGroups
        let (addedNestedGroupIDs, removedNestedGroupIDs) = finalNestedGroups.difference(from: initialNestedGroups)
        let initialMembers = self.members
        let finalMembers = members
        let (addedMemberIDs, removedMemberIDs) = finalMembers.difference(from: initialMembers)
        let groupUUIDsToUpdate = addedOwnerIDs.union(removedOwnerIDs).union(addedNestedGroupIDs).union(removedNestedGroupIDs)
        let userUUIDsToUpdate = addedMemberIDs.union(removedMemberIDs)
        dataProvider.completeManagedObjects(ofType: MutableManagedUserGroup.self, withUUIDs: Array(groupUUIDsToUpdate)) {
            (groupDict, error) in
            guard error == nil else {
                completion(EasyLoginError.debug(String.init(describing: error)))
                return
            }
            dataProvider.completeManagedObjects(ofType: MutableManagedUser.self, withUUIDs: Array(userUUIDsToUpdate)) {
                userDict, error in
                guard error == nil else {
                    completion(EasyLoginError.debug(String.init(describing: error)))
                    return
                }
                // TODO: detect cycles (build trees recursively for owners and nested groups). This implies a citical section.
                addedOwnerIDs.forEach {
                    uuid in
                    if let nested = groupDict[uuid]?.nestedGroups {
                        groupDict[uuid]!.setNestedGroups(nested + [self.uuid])
                    }
                }
                removedOwnerIDs.forEach {
                    uuid in
                    if var nested = groupDict[uuid]?.nestedGroups {
                        if let found = nested.index(of: self.uuid) {
                            nested.remove(at: found)
                        }
                        groupDict[uuid]!.setNestedGroups(nested)
                    }
                }
                addedNestedGroupIDs.forEach {
                    uuid in
                    if let owners = groupDict[uuid]?.memberOf {
                        groupDict[uuid]!.setOwners(owners + [self.uuid])
                    }
                }
                removedNestedGroupIDs.forEach {
                    uuid in
                    if var owners = groupDict[uuid]?.memberOf {
                        if let found = owners.index(of: self.uuid) {
                            owners.remove(at: found)
                        }
                        groupDict[uuid]!.setOwners(owners)
                    }
                }
                addedMemberIDs.forEach {
                    uuid in
                    if let owners = userDict[uuid]?.memberOf {
                        userDict[uuid]!.setOwners(owners + [self.uuid])
                    }
                }
                removedMemberIDs.forEach {
                    uuid in
                    if var owners = userDict[uuid]?.memberOf {
                        if let found = owners.index(of: self.uuid) {
                            owners.remove(at: found)
                        }
                        userDict[uuid]!.setOwners(owners)
                    }
                }
                let groupList = groupDict.map { $1 }
                let userList = userDict.map { $1 }
                // TODO: erase type? We should be able to use [MutableManagedObject]
                dataProvider.storeChangesFrom(mutableManagedObjects: groupList) {
                    (_, error) in
                    guard error == nil else {
                        completion(EasyLoginError.debug(String.init(describing: error)))
                        return
                    }
                    dataProvider.storeChangesFrom(mutableManagedObjects: userList) {
                        (_, error) in
                        guard error == nil else {
                            completion(EasyLoginError.debug(String.init(describing: error)))
                            return
                        }
                        self.setOwners(memberOf)
                        self.setNestedGroups(nestedGroups)
                        self.setMembers(members)
                        completion(nil)
                    }
                }
            }
        }
    }
    
    internal func setOwners(_ value: [String]) {
        guard value != memberOf else {
            return
        }
        memberOf = value
        hasBeenEdited = true
    }
    
    internal func setNestedGroups(_ value: [String]) {
        guard value != nestedGroups else {
            return
        }
        nestedGroups = value
        hasBeenEdited = true
    }
    
    internal func setMembers(_ value: [String]) {
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
