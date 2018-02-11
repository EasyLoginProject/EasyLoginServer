//
//  ManagedObject.swift
//  DataProvider
//
//  Created by Yoann Gini on 01/01/2018.
//

import Foundation
import Extensions

public typealias ManagedObjectRecordID = String

public extension CodingUserInfoKey {
    static let managedObjectCodingStrategy = CodingUserInfoKey(rawValue: "managedObjectCodingStrategy")!
}

public enum ManagedObjectCodingStrategy {
    case databaseEncoding
    case briefEncoding
}

public protocol MutableManagedObject {
    var hasBeenEdited: Bool { get }
}

public class ManagedObject : Codable, Equatable, CustomDebugStringConvertible {
    public let uuid: ManagedObjectRecordID
    public fileprivate(set) var created: Date
    public fileprivate(set) var modified: Date
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
        case created
        case modified
        case deleted
        case recordType = "type"
    }
    
    enum ManagedObjectPartialDatabaseCodingKeys: String, CodingKey {
        case uuid = "uuid"
        case modified
        case deleted
        case recordType = "type"
    }
    
    init() {
        uuid = UUID().uuidString
        isPartialRepresentation = false
        deleted = false
        recordType = "abstract"
        created = Date()
        modified = created
    }
    
    required public init(from decoder: Decoder) throws {
        let codingStrategy = decoder.userInfo[.managedObjectCodingStrategy] as? ManagedObjectCodingStrategy
        
        switch codingStrategy {
        case .databaseEncoding?, .none:
            let container = try decoder.container(keyedBy: ManagedObjectDatabaseCodingKeys.self)
            uuid = try container.decode(ManagedObjectRecordID.self, forKey: .uuid)
            revision = try container.decode(String.self, forKey: .revision)
            recordType = try container.decode(String.self, forKey: .recordType)
            isPartialRepresentation = false
            let deletedMark = try? container.decode(Bool.self, forKey: .deleted)
            deleted = deletedMark ?? false
            created = try container.decode(Date.self, forKey: .created)
            modified = try container.decode(Date.self, forKey: .modified)
        case .briefEncoding?:
            let container = try decoder.container(keyedBy: ManagedObjectPartialDatabaseCodingKeys.self)
            recordType = try container.decode(String.self, forKey: .recordType)
            uuid = try container.decode(ManagedObjectRecordID.self, forKey: .uuid)
            isPartialRepresentation = true
            let deletedMark = try? container.decode(Bool.self, forKey: .deleted)
            deleted = deletedMark ?? false
            created = Date.distantPast
            modified = try container.decode(Date.self, forKey: .modified)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        assert(encoder.userInfo[.managedObjectCodingStrategy] == nil, "Encoding strategy is not supported when writing to database.")
        var container = encoder.container(keyedBy: ManagedObjectDatabaseCodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(recordType, forKey: .recordType)
        if deleted {
            try container.encode(deleted, forKey: .deleted)
        }
        try container.encode(created, forKey: .created)
        try container.encode(modified, forKey: .modified)
    }
    
    static func objectFromJSON(data jsonData:Data, withCodingStrategy strategy:ManagedObjectCodingStrategy) throws -> Self {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        jsonDecoder.userInfo[.managedObjectCodingStrategy] = strategy
        
        return try jsonDecoder.decode(self, from: jsonData)
    }
    
    func jsonData() throws -> Data {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        
        return try jsonEncoder.encode(self)
    }
    
    class func requireFullObject() -> Bool {
        return false
    }
    
    func markAsDeleted() {
        deleted = true
    }
    
    func markAsModified() {
        modified = Date()
    }
}

