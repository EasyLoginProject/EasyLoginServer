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

struct ManagedUser { // PersistentRecord, Serializable
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
    }
    
    let uuid: String
    var numericID: Int
    let shortName: String
    let principalName: String
    let email: String
    let givenName: String?
    let surname: String?
    let fullName: String
    let authMethods: [String: String]

    let type = "user"
}

extension ManagedUser { // PersistentRecord
    /*
    init(database:Database, uuid:UUID) {
        // move to caller
    }
    
    func persist(to database:Database) {
        // move to caller
    }
 */
    
    init?(databaseRecord:JSON) {
        guard let uuid = databaseRecord["_id"].string else { return nil }
        guard let numericID = databaseRecord[Key.numericID.rawValue].int else { return nil }
        guard let shortName = databaseRecord[Key.shortname.rawValue].string else { return nil }
        guard let principalName = databaseRecord[Key.principalName.rawValue].string else { return nil }
        guard let email = databaseRecord[Key.email.rawValue].string else { return nil }
        guard let fullName = databaseRecord[Key.fullName.rawValue].string else { return nil }
        guard let authMethods = databaseRecord[Key.authMethods.rawValue].dictionary else { return nil }
        self.uuid = uuid
        self.numericID = numericID
        self.shortName = shortName
        self.principalName = principalName
        self.email = email
        self.givenName = databaseRecord[Key.givenName.rawValue].string
        self.surname = databaseRecord[Key.surname.rawValue].string
        self.fullName = fullName
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
            "_id": uuid,
            Key.type.rawValue: type,
            Key.numericID.rawValue: numericID,
            Key.shortname.rawValue: shortName,
            Key.principalName.rawValue: principalName,
            Key.email.rawValue: email,
            Key.fullName.rawValue: fullName,
            Key.authMethods.rawValue: authMethods
        ]
        if let givenName = givenName {
            record["givenName"] = givenName
        }
        if let surname = surname {
            record["surname"] = surname
        }
        return record
    }
}

extension ManagedUser { // ServerAPI
    init?(requestElement:JSON) {
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
        self.uuid = uuid
        self.shortName = shortName
        self.principalName = principalName
        self.email = email
        self.givenName = requestElement[Key.givenName.rawValue].string
        self.surname = requestElement[Key.surname.rawValue].string
        self.fullName = fullName
        self.authMethods = generatedAuthMethods
        self.numericID = 0 // FIXME: temporary, psu_demo branch only
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
            record["givenName"] = givenName
        }
        if let surname = surname {
            record["surname"] = surname
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
