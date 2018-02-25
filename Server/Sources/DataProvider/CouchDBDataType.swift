//
//  CouchDBDataType.swift
//  EasyLoginPackageDescription
//
//  Created by Yoann Gini on 02/01/2018.
//

import Foundation


struct CouchDBViewKey: Codable {
    let stringValue:String?
    let intValue:Int?
    
    enum CouchDBViewKeyError: Error {
        case unsupportedKeyType
    }
    
    enum CouchDBViewKeyType {
        case string
        case int
    }
    
    init(from decoder:Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(String.self) {
            stringValue = value
            intValue = nil
        } else if let value = try? container.decode(Int.self) {
            stringValue = nil
            intValue = value
        } else {
            throw CouchDBViewKeyError.unsupportedKeyType
        }
    }
}

struct CouchDBViewKeys: Codable {
    let allKeys: [CouchDBViewKey]
    
    init(from decoder:Decoder) throws {
        if var unkeyedContainer = try? decoder.unkeyedContainer(),
            let multipleValue = try? unkeyedContainer.decode([CouchDBViewKey].self) {
            allKeys = multipleValue
        } else {
            let singleValueContainer = try decoder.singleValueContainer()
            let singleValue = try singleValueContainer.decode(CouchDBViewKey.self)
            allKeys = [singleValue]
        }
    }
}

struct CouchDBViewResult<T: ManagedObject>: Codable {
    let rows: [CouchDBViewRow<T>]
    let offset: Int
    let total_rows: Int
    
    static func objectFromJSON(data jsonData:Data, withCodingStrategy strategy:ManagedObjectCodingStrategy) throws -> CouchDBViewResult<T> {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        jsonDecoder.userInfo[.managedObjectCodingStrategy] = strategy
        
        return try jsonDecoder.decode(self, from: jsonData)
    }
}

struct CouchDBViewRow<T: ManagedObject>: Codable {
    let value: T
    let id: String
    let key:CouchDBViewKeys
    
    enum CouchDBViewRowCodingKeys: CodingKey {
        case value
        case doc
        case id
        case key
    }
    
    init(from decoder:Decoder) throws {
        let container = try decoder.container(keyedBy: CouchDBViewRowCodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        key = try container.decode(CouchDBViewKeys.self, forKey: .key)
        
        if let codingStrategy = decoder.userInfo[.managedObjectCodingStrategy] as? ManagedObjectCodingStrategy,
            codingStrategy == .databaseEncoding,
            container.contains(.doc) {
            value = try container.decode(T.self, forKey: .doc)
        } else {
            value = try container.decode(T.self, forKey: .value)
        }
    }
}

struct CouchDBUpdateResult: Codable {
    let id: String
    let ok: Bool
    let rev: String
}
