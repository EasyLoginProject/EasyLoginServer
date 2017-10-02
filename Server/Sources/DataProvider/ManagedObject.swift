//
//  ManagedObject.swift
//  EasyLogin
//
//  Created by Yoann Gini on 30/09/2017.
//
//

import Foundation
import CouchDB
import Kitura
import SwiftyJSON
import Extensions

public extension JSON {
    public func mandatoryFieldFromDocument<T>(_ key: String) throws -> T {
        guard let element = self[key].object as? T else { throw EasyLoginError.invalidDocument(key) }
        return element
    }
    
    public func mandatoryFieldFromRequest<T>(_ key: String) throws -> T {
        guard let field = self[key].object as? T else { throw EasyLoginError.missingField(key) }
        return field
    }
    
    public func optionalElement<T>(_ key: String) -> T? {
        return self[key].object as? T
    }
    
    public func isNull(_ key: String) -> Bool {
        return self[key].exists() && type(of: self[key].object) == NSNull.self
    }
}

public protocol ManagedObjectProtocol {
    init(databaseRecord:JSON) throws
    func responseElement() throws -> JSON
}

public enum ManagedObjectError: Error {
    case notInserted
    case alreadyInserted
    case nullMandatoryField(String)
}

open class ManagedObject : ManagedObjectProtocol {
    open class var objectType : String {return "undefined"}
    
    public fileprivate(set) var revision: String?
    public fileprivate(set) var uuid: String?
    
    public enum CommonKey : String {
        case type
        case uuid
        case databaseUUID = "_id"
        case databaseRevision = "_rev"
    }
    
    
    public required init(databaseRecord: JSON) throws {
        // No type or unexpected type: requested document was not found
        
        guard let documentType: String = databaseRecord.optionalElement(CommonKey.type.rawValue) else { throw EasyLoginError.notFound }
        guard documentType == type(of: self).objectType else { throw EasyLoginError.notFound }
        
        self.uuid = try databaseRecord.mandatoryFieldFromDocument(CommonKey.databaseUUID.rawValue)
        self.revision = databaseRecord.optionalElement(CommonKey.databaseRevision.rawValue)
    }
    
    open func mandatoryPropertiesForDictionaryRepresentation() -> [String:String] {
        return ["uuid": CommonKey.uuid.rawValue]
    }
    
    open func optionalPropertiesForDictionaryRepresentation() -> [String:String] {
        return [String:String]()
    }
    
    open func dictionaryRepresentation() throws -> [String:Any] {
        var dictionaryRepresentation = [String:Any]()
        let mandatoryProperties = mandatoryPropertiesForDictionaryRepresentation()
        let optionalProperties = optionalPropertiesForDictionaryRepresentation()
        
        let m = Mirror(reflecting: self)
        for child in m.children {
            if let propertyName = child.label {
                if let mandatoryDictionaryKey = mandatoryProperties[propertyName] {
                    if let value = self.unwrap(child.value) {
                        dictionaryRepresentation[mandatoryDictionaryKey] = value
                    } else {
                        throw ManagedObjectError.nullMandatoryField(mandatoryDictionaryKey)
                    }
                } else if let optionalDictionaryKey = optionalProperties[propertyName] {
                    dictionaryRepresentation[optionalDictionaryKey] = child.value
                }
            }
        }
        
        return dictionaryRepresentation
    }
    
    private func unwrap(_ subject: Any) -> Any? {
        var value: Any?
        let mirrored = Mirror(reflecting:subject)
        if mirrored.displayStyle != .optional {
            value = subject
        } else if let firstChild = mirrored.children.first {
            value = firstChild.value
        }
        return value
    }
    
    public func responseElement() throws -> JSON{
        return try JSON(dictionaryRepresentation())
    }
    
    public subscript(key: String) -> Any? {
        let m = Mirror(reflecting: self)
        for child in m.children {
            if child.label == key { return child.value }
        }
        return nil
    }

}
