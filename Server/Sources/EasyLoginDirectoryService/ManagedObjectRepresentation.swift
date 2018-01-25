//
//  ManagedObjectRepresentation.swift
//  EasyLoginDirectoryService
//
//  Created by Frank on 25/01/2018.
//

import Foundation
import DataProvider

extension ManagedObject {
    
    class Representation: Encodable {
        let mo: ManagedObject
        
        init(_ managedObject: ManagedObject) {
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
            if encoder.managedObjectViewFormat() == .full {
                // TODO: encode created/modified
                //try container.encode("test", forKey: .created)
            }
        }
    }
}
