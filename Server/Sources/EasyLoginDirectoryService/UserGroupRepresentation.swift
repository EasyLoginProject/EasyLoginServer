//
//  UserGroupRepresentation.swift
//  EasyLoginDirectoryService
//
//  Created by Frank on 25/01/2018.
//

import Foundation
import DataProvider

extension ManagedUserGroup {
    
    class Representation: ManagedObject.Representation<ManagedUserGroup> {
        enum UserGroupAPICodingKeys: String, CodingKey {
            case numericID
            case shortname
            case commonName
            case email
            case memberOf
            case nestedGroups
            case members
        }
        
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
