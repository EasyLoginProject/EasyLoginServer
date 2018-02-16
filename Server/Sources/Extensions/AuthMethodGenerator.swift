//
//  AuthMethodGenerator.swift
//  EasyLogin
//
//  Created by Frank on 30/07/17.
//
//

import Foundation

public class AuthMethodGenerator {
    
    public let pbkdfGenerator: PBKDF2
    
    public init(pbkdfGenerator: PBKDF2 = PBKDF2()) {
        self.pbkdfGenerator = pbkdfGenerator
    }
    
    public func generate(_ authMethods: [String:String]) throws -> [String:String] {
        guard authMethods.count != 0 else { throw EasyLoginError.missingField("authMethods") }
        if let cleartext = authMethods["cleartext"] {
            var generated = authMethods
            generated["cleartext"] = nil
            generated["sha1"] = cleartext.sha1
            generated["sha256"] = cleartext.sha256
            generated["sha512"] = cleartext.sha512
            let pbkdf2 = try pbkdfGenerator.generateString(fromPassword: cleartext)
            generated["pbkdf2"] = pbkdf2
            return generated
        }
        return authMethods
    }
}
