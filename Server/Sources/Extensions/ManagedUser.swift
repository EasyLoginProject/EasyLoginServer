//
//  ManagedUser.swift
//  EasyLogin
//
//  Created by Frank on 30/04/17.
//
//

import Foundation
import CouchDB
import SwiftyJSON
import LoggerAPI

public struct ManagedUser: PersistentRecord { // PersistentRecord, Serializable
    enum Key: String {
        case type
        case uuid
        case numericID
        case shortname
        case principalName
        case email
        case givenName
        case surname
        case fullName
        case authMethods
        case databaseUUID = "_id"
        case databaseRevision = "_rev"
    }
    
    public fileprivate(set) var revision: String?
    public fileprivate(set) var uuid: String?
    public fileprivate(set) var numericID: Int?
    public fileprivate(set) var shortName: String
    public fileprivate(set) var principalName: String
    public fileprivate(set) var email: String
    public fileprivate(set) var givenName: String?
    public fileprivate(set) var surname: String?
    public fileprivate(set) var fullName: String
    public fileprivate(set) var authMethods: [String: String]

    // TODO: implement as an enum
    static let type = "user"
    static let deleted = "user_deleted"
}

public enum ManagedUserError: Error {
    case notInserted
    case alreadyInserted
    case nullMandatoryField(String)
}

fileprivate extension JSON {
    func mandatoryElement<T>(_ key: ManagedUser.Key) throws -> T {
        guard let element = self[key.rawValue].object as? T else { throw EasyLoginError.invalidDocument(key.rawValue) }
        return element
    }
    
    func mandatoryFieldFromRequest<T>(_ key: ManagedUser.Key) throws -> T {
        guard let field = self[key.rawValue].object as? T else { throw EasyLoginError.missingField(key.rawValue) }
        return field
    }
    
    func optionalElement<T>(_ key: ManagedUser.Key) -> T? {
        return self[key.rawValue].object as? T
    }
    
    func isNull(_ key: ManagedUser.Key) -> Bool {
        return self[key.rawValue].exists() && Swift.type(of: self[key.rawValue].object) == NSNull.self
    }
}

public extension ManagedUser { // PersistentRecord
    init(databaseRecord:JSON) throws {
        // No type or unexpected type: requested document was not found
        guard let documentType: String = databaseRecord.optionalElement(.type) else { throw EasyLoginError.notFound }
        guard documentType == ManagedUser.type else { throw EasyLoginError.notFound }
        // TODO: verify not deleted
        // Missing field: document is invalid
        self.revision = databaseRecord.optionalElement(.databaseRevision)
        self.uuid = try databaseRecord.mandatoryElement(.databaseUUID)
        //self.numericID = try databaseRecord.mandatoryElement(.numericID)
        guard let numericID = databaseRecord[Key.numericID.rawValue].int else { throw EasyLoginError.invalidDocument(Key.numericID.rawValue) }
        self.numericID = numericID
        self.shortName = try databaseRecord.mandatoryElement(.shortname)
        self.principalName = try databaseRecord.mandatoryElement(.principalName)
        self.email = try databaseRecord.mandatoryElement(.email)
        self.fullName = try databaseRecord.mandatoryElement(.fullName)
        self.givenName = databaseRecord.optionalElement(.givenName)
        self.surname = databaseRecord.optionalElement(.surname)
        guard let authMethods = databaseRecord[Key.authMethods.rawValue].dictionary else { throw EasyLoginError.invalidDocument(Key.authMethods.rawValue) }
        let filteredAuthMethodsPairs = authMethods.flatMap {
            (key: String, value: JSON) -> (String,String)? in
            if let value = value.string {
                return (key, value)
            }
            return nil
        }
        self.authMethods = Dictionary(filteredAuthMethodsPairs)
    }
    
    func databaseRecord(deleted: Bool = false) throws -> [String:Any] {
        guard let uuid = uuid else { throw ManagedUserError.notInserted }
        guard let numericID = numericID else { throw ManagedUserError.notInserted }
        var record: [String:Any] = [
            Key.databaseUUID.rawValue: uuid,
            Key.type.rawValue: deleted ? ManagedUser.deleted : ManagedUser.type,
            Key.numericID.rawValue: numericID,
            Key.shortname.rawValue: shortName,
            Key.principalName.rawValue: principalName,
            Key.email.rawValue: email,
            Key.fullName.rawValue: fullName,
            Key.authMethods.rawValue: authMethods
        ]
        if let givenName = givenName {
            record[Key.givenName.rawValue] = givenName
        }
        if let surname = surname {
            record[Key.surname.rawValue] = surname
        }
        return record
    }
}

public extension ManagedUser { // ServerAPI
    init(requestElement:JSON, authMethodGenerator: AuthMethodGenerator) throws {
        self.shortName = try requestElement.mandatoryFieldFromRequest(.shortname)
        self.principalName = try requestElement.mandatoryFieldFromRequest(.principalName)
        self.email = try requestElement.mandatoryFieldFromRequest(.email)
        self.fullName = try requestElement.mandatoryFieldFromRequest(.fullName)
        self.givenName = requestElement.optionalElement(.givenName)
        self.surname = requestElement.optionalElement(.surname)
        guard let requestAuthMethods = requestElement[Key.authMethods.rawValue].dictionary else { throw EasyLoginError.missingField(Key.authMethods.rawValue) }
        // TODO: factorize
        let filteredAuthMethodsPairs = requestAuthMethods.flatMap {
            (key: String, value: JSON) -> (String,String)? in
            if let value = value.string {
                return (key, value)
            }
            return nil
        }
        self.authMethods = try authMethodGenerator.generate(Dictionary(filteredAuthMethodsPairs))
    }
    
    func responseElement() throws -> [String: Any] {
        guard let uuid = uuid else { throw ManagedUserError.notInserted }
        guard let numericID = numericID else { throw ManagedUserError.notInserted }
        var record: [String:Any] = [
            Key.uuid.rawValue: uuid,
            Key.numericID.rawValue: numericID,
            Key.shortname.rawValue: shortName,
            Key.principalName.rawValue: principalName,
            Key.email.rawValue: email,
            Key.fullName.rawValue: fullName,
            Key.authMethods.rawValue: authMethods
        ]
        if let givenName = givenName {
            record[Key.givenName.rawValue] = givenName
        }
        if let surname = surname {
            record[Key.surname.rawValue] = surname
        }
        return record
    }
}

public extension ManagedUser { // mutability
    func inserted(newNumericID: Int) throws -> ManagedUser { // TODO: use NumericIDGenerator
        if uuid != nil { throw ManagedUserError.alreadyInserted }
        if numericID != nil { throw ManagedUserError.alreadyInserted }
        var user = self
        user.uuid = UUID().uuidString
        user.numericID = newNumericID
        return user
    }
    
    func updated(with requestElement: JSON, authMethodGenerator: AuthMethodGenerator) throws -> ManagedUser {
        guard !requestElement.isNull(.email) else { throw ManagedUserError.nullMandatoryField(Key.email.rawValue) }
        guard !requestElement.isNull(.fullName) else { throw ManagedUserError.nullMandatoryField(Key.fullName.rawValue) }
        guard !requestElement.isNull(.authMethods) else { throw ManagedUserError.nullMandatoryField(Key.authMethods.rawValue) }
        var user = self
        if let email: String = requestElement.optionalElement(.email) {
            user.email = email
        }
        if let givenName: String = requestElement.optionalElement(.givenName) {
            user.givenName = givenName
        }
        else if requestElement.isNull(.givenName) {
            user.givenName = nil
        }
        if let surname: String = requestElement.optionalElement(.surname) {
            user.surname = surname
        }
        else if requestElement.isNull(.surname) {
            user.surname = nil
        }
        if let fullName: String = requestElement.optionalElement(.fullName) {
            user.fullName = fullName
        }
        if let requestAuthMethods = requestElement[Key.authMethods.rawValue].dictionary {
            // TODO: factorize
            let filteredAuthMethodsPairs = requestAuthMethods.flatMap {
                (key: String, value: JSON) -> (String,String)? in
                if let value = value.string {
                    return (key, value)
                }
                return nil
            }
            user.authMethods = try authMethodGenerator.generate(Dictionary(filteredAuthMethodsPairs))
        }
        return user
    }
}
