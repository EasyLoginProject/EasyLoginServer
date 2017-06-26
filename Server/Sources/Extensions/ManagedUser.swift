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
import Cryptor

public struct ManagedUser { // PersistentRecord, Serializable
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
    }
    
    public fileprivate(set) var uuid: String?
    public fileprivate(set) var numericID: Int?
    public fileprivate(set) var shortName: String
    public fileprivate(set) var principalName: String
    public fileprivate(set) var email: String
    public fileprivate(set) var givenName: String?
    public fileprivate(set) var surname: String?
    public fileprivate(set) var fullName: String
    public fileprivate(set) var authMethods: [String: String]

    static let type = "user"
}

public enum ManagedUserError: Error {
    case notInserted
    case alreadyInserted
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
}

public extension ManagedUser { // PersistentRecord
    init(databaseRecord:JSON) throws {
        // No type or unexpected type: requested document was not found
        guard let documentType: String = databaseRecord.optionalElement(.type) else { throw EasyLoginError.notFound }
        guard documentType == ManagedUser.type else { throw EasyLoginError.notFound }
        // TODO: verify not deleted
        // Missing field: document is invalid
        self.uuid = try databaseRecord.mandatoryElement(.databaseUUID)
        self.numericID = try databaseRecord.mandatoryElement(.numericID)
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
    
    func databaseRecord() throws -> [String:Any] {
        guard let uuid = uuid else { throw ManagedUserError.notInserted }
        guard let numericID = numericID else { throw ManagedUserError.notInserted }
        var record: [String:Any] = [
            Key.databaseUUID.rawValue: uuid,
            Key.type.rawValue: ManagedUser.type,
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
    init(requestElement:JSON) throws {
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
        self.authMethods = try AuthMethods.generate(Dictionary(filteredAuthMethodsPairs))
    }
    
    func responseElement() throws -> JSON {
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
        return JSON(record)
    }
    
    func inserted(newNumericID: Int) throws -> ManagedUser { // TODO: use NumericIDGenerator
        if uuid != nil { throw ManagedUserError.alreadyInserted }
        if numericID != nil { throw ManagedUserError.alreadyInserted }
        var user = self
        user.uuid = UUID().uuidString
        user.numericID = newNumericID
        return user
    }
    
    func updated(with requestElement: JSON) throws -> ManagedUser {
        var user = self
        if let email: String = requestElement.optionalElement(.email) {
            user.email = email
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
            user.authMethods = try AuthMethods.generate(Dictionary(filteredAuthMethodsPairs))
        }
        return user
    }
}

enum AuthMethods {
    static func generate(_ authMethods: [String:String]) throws -> [String:String] {
        guard authMethods.count != 0 else { throw EasyLoginError.missingField(ManagedUser.Key.authMethods.rawValue) }
        if let cleartext = authMethods["cleartext"] {
            var generated = authMethods
            generated["cleartext"] = nil
            generated["sha1"] = cleartext.sha1
            generated["sha256"] = cleartext.sha256
            generated["sha512"] = cleartext.sha512
            // TODO: PBKDF2
            return generated
        }
        return authMethods
    }
}
