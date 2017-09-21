//
//  Authorization.swift
//  EasyLogin
//
//  Created by Frank on 28/08/17.
//
//

import Foundation

public enum AuthorizationResult {
    case granted
    case denied(reason: String)
}

public protocol Authorization {
    func canCreate(_ type: String) -> AuthorizationResult
    func canRead(field: String, from record: PersistentRecord) -> AuthorizationResult
    func canUpdate(field: String, from record: PersistentRecord) -> AuthorizationResult
    func canDelete(_ record: PersistentRecord) -> AuthorizationResult
}
