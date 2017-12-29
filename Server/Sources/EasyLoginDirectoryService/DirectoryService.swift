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

public class EasyLoginDirectoryService {
    let users: Users
    let devices: Devices
    
    public init(database: Database) {
        users = Users(database: database)
        devices = Devices(database: database)
    }
    
    public func router() -> Router {
        let router = Router()
        router.post(middleware:BodyParser())
        router.put(middleware:BodyParser())
        users.installHandlers(to: router)
        devices.installHandlers(to: router)
        return router
    }
}
