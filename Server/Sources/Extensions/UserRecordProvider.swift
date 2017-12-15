//
//  UserRecordProvider.swift
//  EasyLogin
//
//  Created by Frank on 21/09/17.
//
//

public struct UserAuthMethods {
    public let id: String
    public let authMethods: [String: String]
}

public protocol UserRecordProvider {
    func userAuthMethods(login: String, callback: @escaping (UserAuthMethods?) -> Void)
}

