//
//  UserGroupRepresentation.swift
//  EasyLoginDirectoryService
//
//  Created by Frank on 25/01/2018.
//

import Foundation
import DataProvider

extension ManagedUserGroup {
    
    class Representation: ManagedObject.Representation {
        enum UserGroupAPICodingKeys: String, CodingKey {
            case numericID
            case shortname
            case commonName
            case email
            case memberOf
            case nestedGroups
            case members
        }
        
        let mug: ManagedUserGroup
        
        init(_ managedObject: ManagedUserGroup) {
            mug = managedObject
            super.init(managedObject)
        }
        
        override func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: UserGroupAPICodingKeys.self)
            try container.encode(mug.numericID, forKey: .numericID)
            try container.encode(mug.shortname, forKey: .shortname)
            if encoder.managedObjectViewFormat() == .full {
                try container.encode(mug.commonName, forKey: .commonName)
                if let email = mug.email {
                    try container.encode(email, forKey: .email)
                }
                try container.encode(mug.memberOf, forKey: .memberOf)
                try container.encode(mug.nestedGroups, forKey: .nestedGroups)
                try container.encode(mug.members, forKey: .members)
            }
            try super.encode(to: encoder)
        }
    }
}
