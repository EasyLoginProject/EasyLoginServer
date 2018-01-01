//
//  ManagedUser.swift
//  DataProvider
//
//  Created by Yoann Gini on 01/01/2018.
//

import Foundation
import Extensions

enum ManagedUserError: Error {
    case validatingPasswordAgainstPartialRepresentation
    case noAppropriaiteAuthenticationMethodFound
}

enum AuthenticationScheme: String {
    case pbkdf2
}

public class ManagedUser: ManagedObject {
    public fileprivate(set) var numericID: Int
    public fileprivate(set) var shortname: String
    public fileprivate(set) var principalName: String
    public fileprivate(set) var email: String?
    public fileprivate(set) var givenName: String?
    public fileprivate(set) var surname: String?
    public fileprivate(set) var fullName: String?
    public fileprivate(set) var authMethods: [String: String]?
    
    public override var debugDescription: String {
        let objectAddress = String(format:"%2X", unsafeBitCast(self, to: Int.self))
        var desc = "<\(type(of:self)):\(objectAddress) numericID:\(numericID), shortname:\(shortname), principalName:\(principalName)"
        
        if let email = email {
            desc += ", email:\(email)"
        }
        
        if let givenName = givenName {
            desc += ", givenName:\(givenName)"
        }
        
        if let surname = surname {
            desc += ", surname:\(surname)"
        }
        
        if let fullName = fullName {
            desc += ", fullName:\(fullName)"
        }
        
        desc += ", partialRepresentation:\(isPartialRepresentation)>"
        
        return desc
    }
    
    public override class func viewToListThemAll() -> String {
        return "all_users"
    }
    
    enum ManagedUserDatabaseCodingKeys: String, CodingKey {
        case numericID
        case shortname
        case principalName
        case email
        case givenName
        case surname
        case fullName
        case authMethods
    }
    
    enum ManagedUserPartialDatabaseCodingKeys: String, CodingKey {
        case numericID
        case shortname
        case principalName
        case fullName
    }
    
    public required init(from decoder: Decoder) throws {
        let codingStrategy = decoder.userInfo[.managedObjectCodingStrategy] as? ManagedObjectCodingStrategy
        
        switch codingStrategy {
        case .databaseEncoding?, .none:
            let container = try decoder.container(keyedBy: ManagedUserDatabaseCodingKeys.self)
            numericID = try container.decode(Int.self, forKey: .numericID)
            shortname = try container.decode(String.self, forKey: .shortname)
            principalName = try container.decode(String.self, forKey: .principalName)
            email = try container.decode(String.self, forKey: .email)
            givenName = try container.decode(String.self, forKey: .givenName)
            surname = try container.decode(String.self, forKey: .surname)
            fullName = try container.decode(String.self, forKey: .fullName)
            authMethods = try container.decode([String:String].self, forKey: .authMethods)
            
        case .briefEncoding?:
            let container = try decoder.container(keyedBy: ManagedUserPartialDatabaseCodingKeys.self)
            numericID = try container.decode(Int.self, forKey: .numericID)
            shortname = try container.decode(String.self, forKey: .shortname)
            principalName = try container.decode(String.self, forKey: .principalName)
            fullName = try container.decode(String.self, forKey: .fullName)
        }
        
        
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        let codingStrategy = encoder.userInfo[.managedObjectCodingStrategy] as? ManagedObjectCodingStrategy
        
        switch codingStrategy {
        case .databaseEncoding?, .none:
            var container = encoder.container(keyedBy: ManagedUserDatabaseCodingKeys.self)
            try container.encode(numericID, forKey: .numericID)
            try container.encode(shortname, forKey: .shortname)
            try container.encode(principalName, forKey: .principalName)
            try container.encode(email, forKey: .email)
            try container.encode(givenName, forKey: .givenName)
            try container.encode(surname, forKey: .surname)
            try container.encode(fullName, forKey: .fullName)
            try container.encode(authMethods, forKey: .authMethods)
            
        case .briefEncoding?:
            var container = encoder.container(keyedBy: ManagedUserPartialDatabaseCodingKeys.self)
            try container.encode(numericID, forKey: .numericID)
            try container.encode(shortname, forKey: .shortname)
            try container.encode(principalName, forKey: .principalName)
            try container.encode(fullName, forKey: .fullName)
        }
        try super.encode(to: encoder)
    }
    
    /**
     This function validate a clear text password against already loaded authentication infos.
     This does not work on a partial ManagedUser and will throw an excpetion if started on such an object.
     
     If for any reason, no authentication methods can be found, another excpetion will be thrown
     
     - parameter clearTextPassword: the password in clear text
     - returns: a boolean state indicating the check restult
     */
    public func verify(clearTextPassword:String) throws -> Bool {
        if isPartialRepresentation {
            throw ManagedUserError.validatingPasswordAgainstPartialRepresentation
        } else {
            if let authMethods = authMethods, let modularString = authMethods[AuthenticationScheme.pbkdf2.rawValue] {
                return PBKDF2.verifyPassword(clearTextPassword, withString: modularString)
            } else {
                throw ManagedUserError.noAppropriaiteAuthenticationMethodFound
            }
        }
    }
    
}
