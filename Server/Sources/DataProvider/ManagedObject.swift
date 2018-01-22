//
//  ManagedObject.swift
//  DataProvider
//
//  Created by Yoann Gini on 01/01/2018.
//

import Foundation
import Extensions

public extension CodingUserInfoKey {
    static let managedObjectCodingStrategy = CodingUserInfoKey(rawValue: "managedObjectCodingStrategy")!
}

public enum APIView {
    case full
    case list
}

public enum ManagedObjectCodingStrategy : Equatable {
    case databaseEncoding
    case briefEncoding
    case apiEncoding(APIView)
}

public func ==(lhs: ManagedObjectCodingStrategy, rhs: ManagedObjectCodingStrategy) -> Bool {
    switch (lhs, rhs) {
    case (.databaseEncoding, .databaseEncoding):
        return true
    case (.briefEncoding, .briefEncoding):
        return true
    case (let .apiEncoding(view1), let .apiEncoding(view2)):
        return view1 == view2
    default:
        return false
    }
}

public protocol MutableManagedObject {
    var hasBeenEdited: Bool { get }
}

public class ManagedObject : Codable, Equatable, CustomDebugStringConvertible {
    public let uuid: String
    public fileprivate(set) var deleted: Bool
    public fileprivate(set) var revision: String?
    var recordType: String
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
        case deleted
        case recordType = "type"
    }
    
    enum ManagedObjectPartialDatabaseCodingKeys: String, CodingKey {
        case uuid = "uuid"
        case deleted
        case recordType = "type"
    }
    
    enum ManagedObjectAPICodingKeys: String, CodingKey {
        case uuid
    }
    
    init() {
        uuid = UUID().uuidString
        isPartialRepresentation = false
        deleted = false
        recordType = "abstract"
    }
    
    required public init(from decoder: Decoder) throws {
        let codingStrategy = decoder.userInfo[.managedObjectCodingStrategy] as? ManagedObjectCodingStrategy
        
        switch codingStrategy {
        case .databaseEncoding?, .none:
            let container = try decoder.container(keyedBy: ManagedObjectDatabaseCodingKeys.self)
            uuid = try container.decode(String.self, forKey: .uuid)
            revision = try container.decode(String.self, forKey: .revision)
            recordType = try container.decode(String.self, forKey: .recordType)
            isPartialRepresentation = false
            if let deletedMark = try? container.decode(Bool.self, forKey: .deleted) {
                deleted = deletedMark
            } else {
                deleted = false
            }
        case .briefEncoding?:
            let container = try decoder.container(keyedBy: ManagedObjectPartialDatabaseCodingKeys.self)
            recordType = try container.decode(String.self, forKey: .recordType)
            uuid = try container.decode(String.self, forKey: .uuid)
            isPartialRepresentation = true
            if let deletedMark = try? container.decode(Bool.self, forKey: .deleted) {
                deleted = deletedMark
            } else {
                deleted = false
            }
        case .apiEncoding?:
            throw EasyLoginError.debug("not implemented")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        let codingStrategy = encoder.userInfo[.managedObjectCodingStrategy] as? ManagedObjectCodingStrategy
        
        switch codingStrategy {
        case .databaseEncoding?, .none:
            var container = encoder.container(keyedBy: ManagedObjectDatabaseCodingKeys.self)
            try container.encode(uuid, forKey: .uuid)
            try container.encode(recordType, forKey: .recordType)
            if deleted {
                try container.encode(deleted, forKey: .deleted)
            }
            
        case .briefEncoding?:
            var container = encoder.container(keyedBy: ManagedObjectPartialDatabaseCodingKeys.self)
            try container.encode(uuid, forKey: .uuid)
            try container.encode(recordType, forKey: .recordType)
            if deleted {
                try container.encode(deleted, forKey: .deleted)
            }
            
        case .apiEncoding(_)?:
            var container = encoder.container(keyedBy: ManagedObjectAPICodingKeys.self)
            try container.encode(uuid, forKey: .uuid)
        }
    }
    
    static func objectFromJSON(data jsonData:Data, withCodingStrategy strategy:ManagedObjectCodingStrategy) throws -> Self {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.userInfo[.managedObjectCodingStrategy] = strategy
        
        return try jsonDecoder.decode(self, from: jsonData)
    }
    
    func jsonData(withCodingStrategy strategy:ManagedObjectCodingStrategy) throws -> Data {
        let jsonEconder = JSONEncoder()
        jsonEconder.userInfo[.managedObjectCodingStrategy] = strategy
        
        return try jsonEconder.encode(self)
    }
    
    class func requireFullObject() -> Bool {
        return false
    }
    
    func markAsDeleted() {
        deleted = true
    }
    
}

