//
//  UserGroupRepresentation.swift
//  EasyLoginDirectoryService
//
//  Created by Frank on 25/01/2018.
//

import Foundation
import DataProvider

extension ManagedUserGroup {
    
    enum UserGroupAPICodingKeys: String, CodingKey {
        case numericID
        case shortname
        case commonName
        case email
        case memberOf
        case nestedGroups
        case members
    }
    
    class Representation: ManagedObject.Representation<ManagedUserGroup> {
        override func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: UserGroupAPICodingKeys.self)
            try container.encode(mo.numericID, forKey: .numericID)
            try container.encode(mo.shortname, forKey: .shortname)
            if encoder.managedObjectViewFormat() == .full {
                try container.encode(mo.commonName, forKey: .commonName)
                if let email = mo.email {
                    try container.encode(email, forKey: .email)
                }
                try container.encode(mo.memberOf, forKey: .memberOf)
                try container.encode(mo.nestedGroups, forKey: .nestedGroups)
                try container.encode(mo.members, forKey: .members)
            }
            try super.encode(to: encoder)
        }
    }
}

extension MutableManagedUserGroup {

    enum NullableString: Decodable {
        case null
        case value(String)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            }
            else {
                self = .value(try container.decode(String.self))
            }
        }
        
        var optionalValue: String? {
            get {
                switch self {
                case .null:
                    return nil
                case .value(let value):
                    return value
                }
            }
        }
    }
    
    struct UpdateRequest: Decodable {
        let shortname: String?
        let commonName: String?
        let email: NullableString?
        let memberOf: [ManagedObjectRecordID]?
        let nestedGroups: [ManagedObjectRecordID]?
        let members: [ManagedObjectRecordID]?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: UserGroupAPICodingKeys.self)
            shortname = try container.decodeIfPresent(String.self, forKey: .shortname)
            commonName = try container.decodeIfPresent(String.self, forKey: .commonName)
            if container.contains(.email) {
                email = try container.decode(NullableString.self, forKey: .email)
            }
            else {
                email = nil
            }
            memberOf = try container.decodeIfPresent(Array.self, forKey: .memberOf)
            nestedGroups = try container.decodeIfPresent(Array.self, forKey: .nestedGroups)
            members = try container.decodeIfPresent(Array.self, forKey: .members)
        }
    }
    
    func update(with updateRequest: UpdateRequest) throws {
        if let shortname = updateRequest.shortname {
            try self.setShortname(shortname)
        }
        if let commonName = updateRequest.commonName {
            self.setCommonName(commonName)
        }
        if let email = updateRequest.email {
            switch email {
            case .null:
                self.clearEmail()
            case .value(let email):
                try self.setEmail(email)
            }
        }
        if let memberOf = updateRequest.memberOf {
            self.setOwners(memberOf)
        }
        if let nestedGroups = updateRequest.nestedGroups {
            self.setNestedGroups(nestedGroups)
        }
        if let members = updateRequest.members {
            self.setMembers(members)
        }
    }
}
