//
//  UserRepresentation.swift
//  EasyLoginDirectoryService
//
//  Created by Frank on 07/02/2018.
//

import Foundation
import DataProvider
import Extensions

extension ManagedUser {
    
    enum APICodingKeys: String, CodingKey {
        case numericID
        case shortname
        case principalName
        case email
        case givenName
        case surname
        case fullName
        case memberOf
        case authMethods
    }
    
    class Representation: ManagedObjectRepresentation<ManagedUser> {
        override func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: APICodingKeys.self)
            try container.encode(mo.numericID, forKey: .numericID)
            try container.encode(mo.shortname, forKey: .shortname)
            try container.encode(mo.principalName, forKey: .principalName)
            try container.encode(mo.fullName, forKey: .fullName)
            if encoder.managedObjectViewFormat() == .full {
                try container.encode(mo.email, forKey: .email)
                if let givenName = mo.givenName {
                    try container.encode(givenName, forKey: .givenName)
                }
                if let surname = mo.surname {
                    try container.encode(surname, forKey: .surname)
                }
                try container.encode(mo.memberOf, forKey: .memberOf)
                try container.encode(mo.authMethods, forKey: .authMethods)
            }
            try super.encode(to: encoder)
        }
    }
}

extension MutableManagedUser {
    
    enum NullableString: Decodable {
        case null
        case value(String)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            }
            else {
                self = .value(try container.decode(String.self))
            }
        }
        
        var optionalValue: String? {
            get {
                switch self {
                case .null:
                    return nil
                case .value(let value):
                    return value
                }
            }
        }
    }
    
    struct UpdateRequest: Decodable {
        let shortname: String?
        let principalName: String?
        let email: String?
        let givenName: NullableString?
        let surname: NullableString?
        let fullName: String?
        let authMethods: [String:String]?
        let memberOf: [ManagedObjectRecordID]?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: APICodingKeys.self)
            shortname = try container.decodeIfPresent(String.self, forKey: .shortname)
            principalName = try container.decodeIfPresent(String.self, forKey: .principalName)
            email = try container.decodeIfPresent(String.self, forKey: .email)
            if container.contains(.givenName) {
                givenName = try container.decode(NullableString.self, forKey: .givenName)
            }
            else {
                givenName = nil
            }
            if container.contains(.surname) {
                surname = try container.decode(NullableString.self, forKey: .surname)
            }
            else {
                surname = nil
            }
            fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
            authMethods = try container.decodeIfPresent([String:String].self, forKey: .authMethods)
            memberOf = try container.decodeIfPresent(Array.self, forKey: .memberOf)
        }
    }
    
    func update(with updateRequest: UpdateRequest, authMethodGenerator: AuthMethodGenerator, completion: @escaping (Error?) -> Void) {
        do {
            if let shortname = updateRequest.shortname {
                try self.setShortname(shortname)
            }
            if let principalName = updateRequest.principalName {
                try self.setPrincipalName(principalName)
            }
            if let email = updateRequest.email {
                try self.setEmail(email)
            }
            if let givenName = updateRequest.givenName {
                self.setGivenName(givenName.optionalValue)
            }
            if let surname = updateRequest.surname {
                self.setSurname(surname.optionalValue)
            }
            if let fullName = updateRequest.fullName {
                self.setFullName(fullName)
            }
            if let authMethods = updateRequest.authMethods {
                let filteredAuthMethods = try authMethodGenerator.generate(authMethods)
                self.setAuthMethods(filteredAuthMethods)
            }
        }
        catch {
            completion(error)
            return
        }
        if let memberOf = updateRequest.memberOf {
            self.setRelationships(memberOf: memberOf, completion: completion)
        }
        else {
            completion(nil)
        }
    }
}
