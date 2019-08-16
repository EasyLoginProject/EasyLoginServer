//
//  ManagedObjectRepresentation.swift
//  EasyLoginDirectoryService
//
//  Created by Frank on 25/01/2018.
//

import Foundation
import DataProvider

class ManagedObjectRepresentation<T: ManagedObject>: Encodable {
    let mo: T
    
    init(_ managedObject: T) {
        mo = managedObject
    }
    
    enum ManagedObjectAPICodingKeys: String, CodingKey {
        case uuid
        case created
        case modified
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ManagedObjectAPICodingKeys.self)
        try container.encode(mo.uuid, forKey: .uuid)
        try container.encode(mo.modified, forKey: .modified)
        if encoder.managedObjectViewFormat() == .full {
            try container.encode(mo.created, forKey: .created)
        }
    }
}
