//
//  ManagedObject.swift
//  DataProvider
//
//  Created by Yoann Gini on 01/01/2018.
//

import Foundation

public extension CodingUserInfoKey {
    static let managedObjectCodingStrategy = CodingUserInfoKey(rawValue: "managedObjectCodingStrategy")!
}

public enum ManagedObjectCodingStrategy {
    case databaseEncoding
    case briefEncoding
}

public class ManagedObject : Codable, Equatable, CustomDebugStringConvertible {
    public let uuid: String
    public fileprivate(set) var revision: String?
    let isPartialRepresentation: Bool
    
    public class func designFile() -> String {
        return "main_design"
    }
    
    public class func viewToListThemAll() -> String {
        return "ERROR"
    }
    
    public class func viewToListThemAllReturnPartialResult() -> Bool {
        return true
    }
    
    public var debugDescription: String {
        let objectAddress = String(format:"%2X", unsafeBitCast(self, to: Int.self))
        return "<\(type(of:self)):\(objectAddress) UUID: \(uuid), partialRepresentation:\(isPartialRepresentation)>"
    }
    
    public static func ==(lhs: ManagedObject, rhs: ManagedObject) -> Bool {
        return !lhs.isPartialRepresentation && !rhs.isPartialRepresentation && lhs.uuid == rhs.uuid
    }
    
    enum ManagedObjectDatabaseCodingKeys: String, CodingKey {
        case uuid = "_id"
        case revision = "_rev"
    }
    
    enum ManagedObjectPartialDatabaseCodingKeys: String, CodingKey {
        case uuid = "uuid"
    }
    
    required public init(from decoder: Decoder) throws {
        let codingStrategy = decoder.userInfo[.managedObjectCodingStrategy] as? ManagedObjectCodingStrategy
        
        switch codingStrategy {
        case .databaseEncoding?, .none:
            let container = try decoder.container(keyedBy: ManagedObjectDatabaseCodingKeys.self)
            uuid = try container.decode(String.self, forKey: .uuid)
            revision = try container.decode(String.self, forKey: .revision)
            isPartialRepresentation = false
            
        case .briefEncoding?:
            let container = try decoder.container(keyedBy: ManagedObjectPartialDatabaseCodingKeys.self)
            uuid = try container.decode(String.self, forKey: .uuid)
            isPartialRepresentation = true
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        let codingStrategy = encoder.userInfo[.managedObjectCodingStrategy] as? ManagedObjectCodingStrategy
        
        switch codingStrategy {
        case .databaseEncoding?, .none:
            var container = encoder.container(keyedBy: ManagedObjectDatabaseCodingKeys.self)
            try container.encode(uuid, forKey: .uuid)
            
        case .briefEncoding?:
            var container = encoder.container(keyedBy: ManagedObjectPartialDatabaseCodingKeys.self)
            try container.encode(uuid, forKey: .uuid)
        }
    }
    
    public static func objectFromJSON(data jsonData:Data, withCodingStrategy strategy:ManagedObjectCodingStrategy) throws -> Self {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.userInfo[.managedObjectCodingStrategy] = strategy
        
        return try jsonDecoder.decode(self, from: jsonData)
    }
    
    public func jsonData(withCodingStrategy strategy:ManagedObjectCodingStrategy) throws -> Data {
        let jsonEconder = JSONEncoder()
        jsonEconder.userInfo[.managedObjectCodingStrategy] = strategy
        
        return try jsonEconder.encode(self)
    }
    
}

