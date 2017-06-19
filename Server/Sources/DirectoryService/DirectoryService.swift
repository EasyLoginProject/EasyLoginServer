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
    let database: Database
    
    public init(database: Database) {
        self.database = database
    }
    
    public func router() -> Router {
        let router = Router()
        router.installDatabaseUsersHandlers()
        return router
    }
}
