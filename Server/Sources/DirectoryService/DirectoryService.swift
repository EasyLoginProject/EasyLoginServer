//
//  DirectoryService.swift
//  EasyLogin
//
//  Created by Frank on 18/06/17.
//
//

import Foundation
import CouchDB
import Kitura

public class DirectoryService {
    let users: Users
    
    public init(database: Database) {
        users = Users(database: database)
    }
    
    public func router() -> Router {
        let router = Router()
        users.installHandlers(to: router)
        return router
    }
}
