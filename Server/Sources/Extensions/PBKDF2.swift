//
//  PBKDF2.swift
//  EasyLogin
//
//  Created by Frank on 24/07/17.
//
//

import Foundation
import Cryptor

public class PBKDF2 {
    let algorithm: PBKDF.PseudoRandomAlgorithm
    let rounds: uint
    let derivedKeyLength: Int
    let saltLength: Int
    let stringPrefix: String
    
    public init(algorithm: PBKDF.PseudoRandomAlgorithm = .sha512, derivedKeyLength: Int = 32, saltLength: Int = 32, msec: UInt32 = 500) {
        self.algorithm = algorithm
        self.derivedKeyLength = derivedKeyLength
        self.saltLength = saltLength
        self.rounds = uint(PBKDF.calibrate(passwordLength: 32, saltLength: saltLength, algorithm: algorithm, derivedKeyLength: derivedKeyLength, msec: msec))
        self.stringPrefix = PBKDF2.prefix(fromAlgorithm: algorithm)
    }
    
    class func prefix(fromAlgorithm algorithm: PBKDF.PseudoRandomAlgorithm) -> String {
        switch algorithm {
        case .sha1:
            return "pbkdf2"
        case .sha224:
            return "pbkdf2-sha224"
        case .sha256:
            return "pbkdf2-sha256"
        case .sha384:
            return "pbkdf2-sha384"
        case .sha512:
            return "pbkdf2-sha512"
        }
    }
    
    class func algorithm(fromPrefix prefix: String) -> PBKDF.PseudoRandomAlgorithm? {
        switch prefix {
        case "pbkdf2":
            return .sha1
        case "pbkdf2-sha224":
            return .sha224
        case "pbkdf2-sha256":
            return .sha256
        case "pbkdf2-sha384":
            return .sha384
        case "pbkdf2-sha512":
            return .sha512
        default:
            return nil
        }
    }
    
    // modular crypt format
    public func generateString(fromPassword password: String) throws -> String {
        let salt = try Random.generate(byteCount: saltLength)
        let derivedKey = PBKDF.deriveKey(fromPassword: password, salt: salt, prf: algorithm, rounds: rounds, derivedKeyLength: UInt(derivedKeyLength))
        let base64SuffixCharacterSet = CharacterSet(charactersIn: "=")
        let saltString = Data(salt).base64EncodedString().trimmingCharacters(in: base64SuffixCharacterSet)
        let keyString = Data(derivedKey).base64EncodedString().trimmingCharacters(in: base64SuffixCharacterSet)
        let modularString = "$\(stringPrefix)$\(rounds)$\(saltString)$\(keyString)"
        return modularString
    }
    
    public static func verifyPassword(_ password: String, withString modularString: String) -> Bool {
        let components = modularString.components(separatedBy: CharacterSet(charactersIn: "$"))
        guard components.count == 5 else { return false }
        let (prefixString, roundsString, saltString, hashString) = (components[1], components[2], components[3], components[4])
        guard
            let prf = self.algorithm(fromPrefix: prefixString),
            let rounds = Int(roundsString),
            let saltData = Data(base64Encoded: saltString),
            let hashData = Data(base64Encoded: hashString)
        else {
            return false
        }
        let salt = Array(saltData)
        let hash = Array(hashData)
        let derivedHash = PBKDF.deriveKey(fromPassword: password, salt: salt, prf: prf, rounds: uint(rounds), derivedKeyLength: 32)
        return derivedHash == hash
    }
}
