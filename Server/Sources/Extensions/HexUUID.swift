//
//  HexUUID.swift
//  EasyLogin
//
//  Created by Frank on 14/05/17.
//
//

import Foundation

public extension UUID {
    func hexString() -> String {
        let u = self.uuid
        let hexString = String(format: "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7, u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15)
        return hexString
    }
}
