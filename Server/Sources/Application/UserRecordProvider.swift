//
//  UserRecordProvider.swift
//  EasyLogin
//
//  Created by Frank on 21/09/17.
//
//

import Extensions

struct UserAuthMethods {
    let id: String
    let authMethods: [String: String]
}

protocol UserRecordProvider {
    func userAuthMethods(login: String, callback: @escaping (UserAuthMethods?) -> Void)
}

