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
    
    public let uuid: String
    public var numericID: Int
    public let shortName: String
    public let principalName: String
    public let email: String
    public let givenName: String?
    public let surname: String?
    public let fullName: String
    public let authMethods: [String: String]

    static let type = "user"
}

extension JSON {
    func mandatoryElement<T>(_ key: ManagedUser.Key) throws -> T {
        guard let element = self[key.rawValue].object as? T else { throw EasyLoginError.invalidDocument(key.rawValue) }
        return element
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
    
    func databaseRecord() -> [String:Any] {
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
    init?(requestElement:JSON) {
        //guard let numericID = requestElement[Key.numericID.rawValue].int else { return nil }
        guard let shortName = requestElement[Key.shortname.rawValue].string else { return nil }
        Log.debug("short name = \(shortName)")
        guard let principalName = requestElement[Key.principalName.rawValue].string else { return nil }
        Log.debug("principal name = \(principalName)")
        guard let email = requestElement[Key.email.rawValue].string else { return nil }
        guard let fullName = requestElement[Key.fullName.rawValue].string else { return nil }
        guard let requestAuthMethods = requestElement[Key.authMethods.rawValue].dictionary else { return nil }
        let filteredAuthMethodsPairs = requestAuthMethods.flatMap {
            (key: String, value: JSON) -> (String,String)? in
            if let value = value.string {
                return (key, value)
            }
            return nil
        }
        guard let generatedAuthMethods = AuthMethods.generate(Dictionary(filteredAuthMethodsPairs)) else { return nil }
        let uuid = UUID().uuidString
        let numericID = 123 // TODO: generate
        self.uuid = uuid
        self.numericID = numericID
        self.shortName = shortName
        self.principalName = principalName
        self.email = email
        self.givenName = requestElement[Key.givenName.rawValue].string
        self.surname = requestElement[Key.surname.rawValue].string
        self.fullName = fullName
        self.authMethods = generatedAuthMethods
    }
    
    func responseElement() -> JSON {
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
}

enum AuthMethods {
    static func generate(_ authMethods: [String:String]) -> [String:String]? {
        guard authMethods.count != 0 else { return nil }
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
