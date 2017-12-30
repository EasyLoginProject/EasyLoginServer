//
//  CouchDBProvider.swift
//  EasyLogin
//
//  Created by Frank on 21/09/17.
//
//

import CouchDB
import SwiftyJSON

extension Database: UserRecordProvider {
    public func userAuthMethods(login: String, callback: @escaping (UserAuthMethods?) -> Void) {
        self.queryByView("user_authMethods_by_shortname", ofDesign: "main_design", usingParameters: [.keys([login as KeyType])]) { (databaseResponse, error) in
            guard let databaseResponse = databaseResponse else {
                // TODO: report error
                callback(nil)
                return
            }
            let results = databaseResponse["rows"].array?.flatMap { row -> UserAuthMethods? in
                if let id = row["id"].string,
                   let authMethodsDict = row["value"].dictionary {
                    let filteredAuthMethodsPairs = authMethodsDict.flatMap {
                        (key: String, value: JSON) -> (String,String)? in
                        if let value = value.string {
                            return (key, value)
                        }
                        return nil
                    }
                    let authMethods = Dictionary(filteredAuthMethodsPairs)
                    return UserAuthMethods(id: id, authMethods: authMethods)
                }
                return nil
            }
            let result = results?.first
            callback(result)
        }
    }
}
