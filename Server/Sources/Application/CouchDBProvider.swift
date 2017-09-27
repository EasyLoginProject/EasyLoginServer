//
//  CouchDBProvider.swift
//  EasyLogin
//
//  Created by Frank on 21/09/17.
//
//

import CouchDB
import Extensions

extension Database: UserRecordProvider {
    func user(login: String) -> ManagedUser? {
        return nil
    }
}
