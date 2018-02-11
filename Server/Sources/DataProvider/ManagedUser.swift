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
    case noAppropriateAuthenticationMethodFound
}

enum AuthenticationScheme: String {
    case pbkdf2
}

public class ManagedUser: ManagedObject {
    public fileprivate(set) var numericID: Int
    public fileprivate(set) var shortname: String
    public fileprivate(set) var principalName: String
    public fileprivate(set) var email: String? // not optional
    public fileprivate(set) var givenName: String?
    public fileprivate(set) var surname: String?
    public fileprivate(set) var fullName: String? // not optional
    public fileprivate(set) var authMethods: [String: String]? // not optional
    public fileprivate(set) var memberOf: [ManagedObjectRecordID]
    
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
        case memberOf
    }
    
    enum ManagedUserPartialDatabaseCodingKeys: String, CodingKey {
        case numericID
        case shortname
        case principalName
        case fullName
    }
    
    
    fileprivate init(withDataProvider dataProvider: DataProvider, numericID:Int, shortname:String, principalName:String, email:String?, givenName:String?, surname:String?, fullName:String?, authMethods:[String:String] = [:], memberOf:[ManagedObjectRecordID] = []) {
        self.numericID = numericID
        self.shortname = shortname
        self.principalName = principalName
        self.email = email
        self.givenName = givenName
        self.surname = surname
        self.fullName = fullName
        self.authMethods = authMethods
        self.memberOf = memberOf
        super.init(withDataProvider: dataProvider)
        recordType = "user"
    }
    
    public convenience init(with mo: ManagedUser) {
        assert(mo.dataProvider != nil, "Copying a temporary object is not supported.")
        self.init(withDataProvider: mo.dataProvider!, numericID: mo.numericID, shortname: mo.shortname, principalName: mo.principalName, email: mo.email, givenName: mo.givenName, surname: mo.surname, fullName: mo.fullName, authMethods: mo.authMethods ?? [:], memberOf: mo.memberOf)
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
            givenName = try container.decodeIfPresent(String.self, forKey: .givenName)
            surname = try container.decodeIfPresent(String.self, forKey: .surname)
            fullName = try container.decode(String.self, forKey: .fullName)
            authMethods = try container.decode([String:String].self, forKey: .authMethods)
            memberOf = try container.decode([ManagedObjectRecordID].self, forKey: .memberOf)
            
        case .briefEncoding?:
            let container = try decoder.container(keyedBy: ManagedUserPartialDatabaseCodingKeys.self)
            numericID = try container.decode(Int.self, forKey: .numericID)
            shortname = try container.decode(String.self, forKey: .shortname)
            principalName = try container.decode(String.self, forKey: .principalName)
            fullName = try container.decode(String.self, forKey: .fullName)
            memberOf = []
        }
        
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ManagedUserDatabaseCodingKeys.self)
        try container.encode(numericID, forKey: .numericID)
        try container.encode(shortname, forKey: .shortname)
        try container.encode(principalName, forKey: .principalName)
        try container.encode(email, forKey: .email)
        if let givenName = givenName {
            try container.encode(givenName, forKey: .givenName)
        }
        if let surname = surname {
            try container.encode(surname, forKey: .surname)
        }
        try container.encode(fullName, forKey: .fullName)
        try container.encode(authMethods, forKey: .authMethods)
        try container.encode(memberOf, forKey: .memberOf)
        try super.encode(to: encoder)
    }
    
    /**
     This function validates a clear text password against already loaded authentication data.
     This does not work on a partial ManagedUser and will throw an exception if started on such an object.
     
     If for any reason, no authentication methods can be found, another exception will be thrown.
     
     - parameter clearTextPassword: the password in clear text
     - returns: a boolean state indicating the check result
     */
    public func verify(clearTextPassword:String) throws -> Bool {
        guard !isPartialRepresentation else {
            throw ManagedUserError.validatingPasswordAgainstPartialRepresentation
        }
        if let authMethods = authMethods, let modularString = authMethods[AuthenticationScheme.pbkdf2.rawValue] {
            return PBKDF2.verifyPassword(clearTextPassword, withString: modularString)
        } else {
            throw ManagedUserError.noAppropriateAuthenticationMethodFound
        }
    }
}

public class MutableManagedUser : ManagedUser, MutableManagedObject {
    public fileprivate(set) var hasBeenEdited = false
    
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
        
        desc += ", partialRepresentation:\(isPartialRepresentation)"
        desc += ", hasBeenEdited:\(hasBeenEdited)>"
        
        return desc
    }
    
    enum MutableManagedUserUpdateError: Error {
        case invalidShortname
        case invalidPrincipalName
        case invalidEmail
    }
    
    public override init(withDataProvider dataProvider: DataProvider, numericID:Int, shortname:String, principalName:String, email:String?, givenName:String?, surname:String?, fullName:String?, authMethods:[String:String] = [:], memberOf:[ManagedObjectRecordID] = []) {
        hasBeenEdited = true
        super.init(withDataProvider: dataProvider, numericID: numericID, shortname: shortname, principalName: principalName, email: email, givenName: givenName, surname: surname, fullName: fullName, authMethods: authMethods, memberOf: memberOf)
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
    
    public func setShortname(_ value:String) throws {
        guard value != shortname else {
            return
        }
        guard value.range(of: "^[a-z_][a-z0-9_-]{0,30}$", options: .regularExpression, range: nil, locale: nil) != nil else {
            throw MutableManagedUserUpdateError.invalidShortname
        }
        shortname = value
        hasBeenEdited = true
    }
    
    public func setPrincipalName(_ value:String) throws {
        guard value != principalName else {
            return
        }
        guard value.range(of: "^[a-z0-9_.-]+@[A-Za-z0-9.-]+$", options: .regularExpression, range: nil, locale: nil) != nil else {
            throw MutableManagedUserUpdateError.invalidPrincipalName
        }
        principalName = value
        hasBeenEdited = true
    }
    
    public func setEmail(_ value:String) throws {
        guard value != email else {
            return
        }
        guard value.range(of: "^[a-z0-9_.-]+@[A-Za-z0-9.-]+$", options: .regularExpression, range: nil, locale: nil) != nil else {
            throw MutableManagedUserUpdateError.invalidEmail
        }
        email = value
        hasBeenEdited = true
    }
    
    public func setGivenName(_ value:String?) {
        guard value != givenName else {
            return
        }
        
        givenName = value
        hasBeenEdited = true
    }
    
    public func setSurname(_ value:String?) {
        guard value != surname else {
            return
        }
        
        surname = value
        hasBeenEdited = true
    }
    
    public func setFullName(_ value:String) {
        guard value != fullName else {
            return
        }
        
        fullName = value
        hasBeenEdited = true
    }
    
    public func setAuthMethods(_ value: [String:String]) {
        guard authMethods == nil || value != authMethods! else {
            return
        }
        
        authMethods = value
        hasBeenEdited = true
    }
    
    public func setOwners(_ value: [String]) {
        guard value != memberOf else {
            return
        }
        memberOf = value
        hasBeenEdited = true
    }
    
    public func setClearTextPasssword(_ value:String) throws {
        var generated = [String:String]()
        
        generated["sha1"] = value.sha1
        generated["sha256"] = value.sha256
        generated["sha512"] = value.sha512
        let pbkdf2 = try PBKDF2().generateString(fromPassword: value)
        generated["pbkdf2"] = pbkdf2
        
        authMethods = generated
        hasBeenEdited = true
    }
    
    override class func requireFullObject() -> Bool {
        return true
    }
}
