//
//  ManagedObjectFormatter.swift
//  EasyLoginDirectoryService
//
//  Created by Frank on 25/01/2018.
//

import Foundation
import DataProvider

extension CodingUserInfoKey {
    static let viewFormat = CodingUserInfoKey(rawValue: "viewFormat")!
}

enum ManagedObjectViewFormat {
    case summary
    case full
}

class ManagedObjectFormatter<T: ManagedObject> {
    
    typealias RepresentationGenerator = (_ object: T) -> ManagedObjectRepresentation<T>
    
    enum Error {
        case missingViewFormat
    }
    
    let summaryJSONEncoder: JSONEncoder
    let generator: RepresentationGenerator
    
    init(type: T.Type, generator: @escaping RepresentationGenerator) {
        summaryJSONEncoder = JSONEncoder()
        summaryJSONEncoder.dateEncodingStrategy = .iso8601
        summaryJSONEncoder.userInfo[.viewFormat] = ManagedObjectViewFormat.summary
        self.generator = generator
    }
    
    func summaryAsJSONData(_ object: T) throws -> Data {
        let representation = generator(object)
        return try summaryJSONEncoder.encode(representation)
    }
    
    func summaryAsJSONData(_ list: [T], withRootKey rootKey:String) throws -> Data {
        let representations = list.map(generator)
        return try summaryJSONEncoder.encode([rootKey:representations])
    }
    
    func viewAsJSONData(_ object: T) throws -> Data { // TODO: add view options here
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.userInfo[.viewFormat] = ManagedObjectViewFormat.full
        let representation = generator(object)
        return try jsonEncoder.encode(representation)
    }
}

extension Encoder {
    func managedObjectViewFormat() -> ManagedObjectViewFormat {
        guard let viewFormat = userInfo[.viewFormat] as? ManagedObjectViewFormat else {
            preconditionFailure("Missing or invalid viewFormat in JSON encoder userInfo.")
        }
        return viewFormat
    }
}
