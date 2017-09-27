//
//  UserRecordProvider.swift
//  EasyLogin
//
//  Created by Frank on 21/09/17.
//
//

import Extensions

protocol UserRecordProvider {
    func user(login: String) -> ManagedUser?
}

